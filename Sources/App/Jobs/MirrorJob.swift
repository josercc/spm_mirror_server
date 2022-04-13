import Vapor
import Queues
import FluentKit
struct MirrorJob: MirrorAsyncJob {
    func dequeue(_ context: QueueContext, _ payload: PayloadData) async throws {
        context.logger.info("开启自动任务->>")
        /// 查询是否还有未完成的任务 包含制作超时的任务
        let waitMirrors = try await Mirror.query(on: context.application.db).filter(\.$isExit == false).all()
        for waitMirror in waitMirrors {
            /// 查询镜像是否在 gitee 存在
            let exitStatus = try await checkMirrorRepoExit(context, payload, waitMirror.origin, waitMirror.mirror)
            if exitStatus == .repoExit {
                try await success(context, payload, waitMirror.origin)
                return
            }
            if exitStatus == .repoEmpty {
                /// 仓库存在但是为空
                /// 删除空仓库
                try await deleteRepo(context, payload, waitMirror.mirror, waitMirror.origin)
            }
            if exitStatus == .repoExitOther {
                /// 仓库存在但是内容不一致
                WeiXinWebHooks.sendContent("警告：\(waitMirror.mirror)和\(waitMirror.origin)仓库不一致", context.application, payload.config)
                throw Abort(.custom(code: 10000, reasonPhrase: "仓库存在但是内容不一致"))
            }
            /// 如果等待次数小于6 才允许执行等待
            if waitMirror.waitCount <= 2, waitMirror.waitProgressCount <= 120 {
                try await wait(context, payload, waitMirror)
                return
            } else {
                continue
            }
        }
        /// 查询是否还有没有创建镜像的队列
        let mirrorStack = try await MirrorStack.query(on: context.application.db).sort(\.$create, .descending).first()
        /// 如果镜像队列存在则开启镜像任务
        if let mirrorStack = mirrorStack {
            let mirrors = try await Mirror.query(on: context.application.db).filter(\.$origin == mirrorStack.url).all()
            if mirrors.count > 0 {
                try await mirrorStack.delete(on: context.application.db)
                try await start(context, payload)
            } else {
                try await create(context, payload, mirrorStack.url)
            }
            return
        }
        /// 获取需要进行更新的镜像
        let needUpdateMirror = try await Mirror.query(on: context.application.db).filter(\.$needUpdate == true).first()
        /// 如果需要进行更新的镜像存在则开启更新任务
        if let needUpdateMirror = needUpdateMirror {
            try await update(context, payload, needUpdateMirror.origin, needUpdateMirror.mirror)
            return
        }
        /// 获取现在时间的时间戳
        let now = Date().timeIntervalSince1970
        /// 获取一周之前的时间戳
        let weekAgo = now - 604800
        /// 获取所有请求镜像次数超过 1000 次的仓库 并且最后更新时间小于当前时间一周的仓库
        let needUpdateMirrors = try await Mirror.query(on: context.application.db).filter(\.$requestMirrorCount >= 1000).filter(\.$lastMittorDate <= weekAgo).all()
        guard needUpdateMirrors.count > 0 else {
            context.logger.info("没有需要更新的镜像->>")
            return
        }
        /// 将镜像的最后更新时间小于一周的更新需要更新
        for mirror in needUpdateMirrors {
            mirror.needUpdate = true
            try await mirror.save(on: context.application.db)
        }
        try await start(context, payload)
    }
    typealias Payload = PayloadData
}


extension MirrorJob {
    func wait(_ context: QueueContext, _ payload: PayloadData, _ mirror:Mirror) async throws {
        context.logger.info("开始等待镜像完毕: \(String(describing: mirror.id)) \(String(describing: mirror.mirror)) \(String(describing: mirror.origin))")
        /// 获取镜像是否制作完毕 制作完成则开启新的任务
        if mirror.isExit {
            context.logger.info("镜像已经存在开启新任务")
            try await start(context, payload)
            return
        }
        /// 创建 Github Api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        let repoPath = repoPath(from: mirror.mirror, host: "https://gitee.com/")
        /// 获取是否有制作镜像的Run状态
        let runStatus = try await githubApi.fetchRunStatus(repo: repoPath, in: context.application.client)
        if runStatus == .success {
            try await success(context, payload, mirror.origin)
            return
        }
        if runStatus == .timeOut,
           let mirror = try await Mirror.find(mirror.id, on: context.application.db) {
            mirror.waitProgressCount = 120
            try await mirror.update(on: context.application.db)
        }
        /// 如果处于等待和制作中 则等待30秒开始新的任务
        if runStatus == .queued || runStatus == .inProgress || runStatus == .timeOut {
            if let mirror = try await Mirror.find(mirror.id, on: context.application.db) {
                var waitProgressCount = mirror.waitProgressCount
                waitProgressCount += 1
                mirror.waitProgressCount = waitProgressCount
                try await mirror.update(on: context.application.db)
                if waitProgressCount > 120 {
                    WeiXinWebHooks.sendContent("\(mirror.origin)制作镜像\(mirror.mirror)制作已经超过了1个小时，请手动导入！",
                                               context.application,
                                               payload.config)
                    let ymlFile = try getYmlFilePath(url: mirror.origin)
                    try await githubApi.deleteYml(fileName: ymlFile, in: context.application.client)
                    try await start(context, payload)
                } else {
                    context.logger.info("镜像正在制作中,延时30秒开启新任务")
                    let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
                        sleep(30)
                    }).get()
                    try await wait(context, payload, mirror)
                }
            }
            return
        }
        context.logger.info("镜像制作失败或者未开始,开始重试任务")
        /// 如果处于失败状态 则增加等待次数
        if runStatus == .failure, let mirror = try await Mirror.find(mirror.id, on: context.application.db) {
            context.logger.info("镜像制作失败,增加等待次数")
            var waitCount = mirror.waitCount
            waitCount += 1
            /// 增加等待次数
            mirror.waitCount = waitCount
            /// 更新镜像数据
            try await mirror.update(on: context.application.db)
            /// 如果等待次数大于2次则微信通知
            if waitCount > 2 {
                context.logger.info("镜像制作失败超过5次,微信通知")
                /// 发送微信通知
                WeiXinWebHooks.sendContent("\(mirror.origin)镜像制作\(mirror.mirror)失败,请检查镜像是否正常制作", context.application, payload.config)
                let ymlFile = try getYmlFilePath(url: mirror.origin)
                try await githubApi.deleteYml(fileName: ymlFile, in: context.application.client)
                try await deleteRepo(context, payload, mirror.mirror, mirror.origin)
                /// 重新开始任务
                try await start(context, payload)
                return
            }
        }
        guard let dst = repoOriginPath(from: mirror.mirror, host: "https://gitee.com/") else {
            throw Abort(.custom(code: 10000, reasonPhrase: "获取镜像组织名称失败"))
        }
        try await deleteRepo(context, payload, mirror.mirror, mirror.origin)
        try await createYml(context, payload, mirror.origin, dst)
    }
}

extension MirrorJob {
    /// 开始新任务
    func start(_ context:QueueContext, _ payload:PayloadData, _ sleepTime:UInt32 = 5) async throws {
        context.logger.info("延时\(sleepTime)秒")
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(sleepTime)
        }).get()
        /// 开启任务
        let payload = MirrorJob.PayloadData(config: payload.config)
        try await context.queue.dispatch(MirrorJob.self, payload)
    }
}

extension MirrorJob {
    func success(_ context:QueueContext, _ payload:PayloadData, _ origin:String) async throws {
        context.logger.info("\(origin)制作镜像成功")
        /// 获取YML文件路径
        let ymlPath = try getYmlFilePath(url: origin)
        /// 创建 Github api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 检测YML文件是否存在
        let ymlExit = try await githubApi.ymlExit(file: ymlPath, in: context.application.client)
        /// 如果 YML存在就删除 YML文件
        if ymlExit {
            try await githubApi.deleteYml(fileName: ymlPath, in: context.application.client)
        }
        for stack in try await MirrorStack.query(on: context.application.db).filter(\.$url == origin).all() {
            try await stack.delete(on: context.application.db)
        }
        /// 查询镜像
        for mirror in try await Mirror.query(on: context.application.db).filter(\.$origin == origin).all() {
            /// 更新是否存在
            mirror.isExit = true
            mirror.needUpdate = false
            mirror.lastMittorDate = Date().timeIntervalSince1970
            mirror.waitCount = 0
            mirror.waitProgressCount = 0
            try await mirror.update(on: context.application.db)            
        }
        try await start(context, payload)
    }
}

extension MirrorJob {
    func createYml(_ context:QueueContext, _ payload: Payload, _ origin:String, _ dst:String) async throws {
        context.logger.info("开始创建YML文件:->>\(origin)")
        /// 创建 Github api
        let githubApi = try GithubApi(app: context.application, token: payload.config.githubToken, repo: payload.config.githubRepo)
        /// 获取最近10条Run运行状态
        let runStatus = try await githubApi.fetchRunStatus(in: context.application.client)
        /// 查询runStatus 是否存在还在运行
        let runStatusExist = runStatus.contains { (run) -> Bool in
            run == .inProgress || run == .queued
        }
        /// 如果处于等待和制作中 则开启新的任务
        if runStatusExist {
            context.logger.info("当前存在运行的任务,等待30秒开启新的任务")
            /// 开启新任务
            try await start(context, payload, 30)
            return
        }
        /// 获取当前项目所有的yml文件
        let ymlFiles = try await githubApi.getContents(name: "josercc", repo: payload.config.githubRepo, path: ".github/workflows")
        for ymlFile in ymlFiles {
            /// 删除yml文件
            try await githubApi.deleteYml(fileName: ymlFile.name, in: context.application.client)
        }
        /// 获取YML文件路径
        let ymlPath = try getYmlFilePath(url: origin)
        guard let src = repoOriginPath(from: origin) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(origin) 获取组织名称失败"))
        }
        /// 检测是否是组织
        let isOrg = try await githubApi.isOrg(name: src, client: context.application.client)
        guard let repo = repoNamePath(from: origin) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(origin) 获取项目名称失败"))
        }
        /// 创建 YML 内容
        let ymlContent = actionContent(src: src, dst: dst, isOrg: isOrg, repo: repo)
        /// 创建 YML文件
        guard try await githubApi.addGithubAction(fileName: ymlPath, content: ymlContent, client: context.application.client) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(origin) 创建YML文件失败"))
        }
        context.logger.info("创建YML文件成功:->>\(origin) 延时30秒开启新任务")
        /// 延时30秒
        let _ = try await context.application.threadPool.runIfActive(eventLoop: context.eventLoop, {
            sleep(30)
        }).get()
        /// 开启新任务
        try await start(context, payload)
    }
}


extension MirrorJob {
    func create(_ context:QueueContext, _ payload:Payload, _ origin:String, _ dst:String? = nil) async throws {
        context.logger.info("开始制作\(origin)镜像")
        /// 获取镜像的组织
        var dst = dst ?? "spm_mirror"
        /// 获取仓库名称
        guard let repo = repoNamePath(from: origin) else {
            throw Abort(.custom(code: 10000, reasonPhrase: "\(origin) 获取项目名称失败"))
        }
        /// 获取镜像仓库地址
        let mirrorRepo = "https://gitee.com/\(dst)/\(repo)"
        /// 检测镜像仓库是否被其他仓库占用
        let mirrorRepoExists = try await Mirror.query(on: context.application.db).filter(\.$mirror == mirrorRepo).filter(\.$origin != origin).count() > 0
        /// 获取镜像在Gitee的状态
        let mirrorStatus = try await checkMirrorRepoExit(context, payload, origin, mirrorRepo)
        /// 如果镜像仓库被其他仓库占用开启新的任务
        if mirrorRepoExists || mirrorStatus == .repoExitOther {
            context.logger.info("镜像仓库被其他仓库占用: \(mirrorRepo)")
            dst += "1"
            try await create(context, payload, origin, dst)
            return
        }
        if mirrorStatus == .repoExit {
            try await success(context, payload, origin)
            return
        } else if mirrorStatus == .repoEmpty {
            /// 删除空的镜像仓库
            try await deleteRepo(context, payload, mirrorRepo, origin)
        }
        /// 如果镜像不存在则保存新镜像
        let count = try await Mirror.query(on: context.application.db).filter(\.$origin == origin).count()
        if count == 0 {
            /// 保存新的镜像
            let mirrorData = Mirror(origin: origin, mirror: mirrorRepo)
            try await mirrorData.save(on: context.application.db)
        }
        /// 创建 YML文件
        try await createYml(context, payload, origin, dst)
    }
}

extension MirrorJob {
    func update(_ context:QueueContext, _ payload:Payload, _ origin:String, _ mirror:String) async throws {
        context.logger.info("开始更新\(origin)镜像")
        /// 获取镜像之后的组织
        guard let dst = repoOriginPath(from: mirror, host: "https://gitee.com/") else {
            throw Abort(.custom(code: 10000, reasonPhrase: "update  repoOriginPath 失败"))
        }
        /// 获取GiteeApi
        let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
        // /// 查询组织是否存在
        let exists = try await giteeApi.checkOrgExit(org: dst, in: context.application.client)
        // /// 如果不存在则创建
        if !exists {
            try await giteeApi.createOrg(client: context.application.client, name: dst)
        }
        for mirror in try await Mirror.query(on: context.application.db).filter(\.$origin == origin).all() {
            mirror.needUpdate = false
            mirror.isExit = false
            try await mirror.update(on: context.application.db)
        }
        /// 创建YML文件
        try await createYml(context, payload, origin, dst)
    }
}

extension MirrorJob {
    func deleteRepo(_ context:QueueContext, _ payload:Payload, _ mirror:String, _ origin:String) async throws {
        /// 获取GiteeApi
        let giteeApi = try GiteeApi(app: context.application, token: payload.config.giteeToken)
        guard let org = repoOriginPath(from: mirror, host: "https://gitee.com/") else {
            throw Abort(.badRequest, reason: "仓库地址错误")
        }
        guard let name = repoNamePath(from: mirror, host: "https://gitee.com/") else {
            throw Abort(.badRequest, reason: "仓库地址错误")
        }
        /// 获取仓库状态
        let repoStatus = try await checkMirrorRepoExit(context, payload, origin, mirror)
        guard repoStatus == .repoEmpty else{
            return
        }   
        /// 删除仓库
        try await giteeApi.deleteRepo(name: org, repo: name, in: context.application.client)
    }
}

extension MirrorJob {
    struct PayloadData: JobPayload {
        var config: MirrorConfigration        
    }
}

/// 管理镜像任务状态
actor MirrorJobStatus {
    var isRunning: Bool = false
    func start() {
        isRunning = true
    }
    func stop() {
        isRunning = false
    }
}

let mirrorJobStatus = MirrorJobStatus()
