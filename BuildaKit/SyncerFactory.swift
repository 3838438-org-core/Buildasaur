//
//  SyncerFactory.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 10/3/15.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Foundation
import XcodeServerSDK
import BuildaGitServer

public protocol SyncerFactoryType {
    func createSyncers(configs: [ConfigTriplet]) -> [HDGitHubXCBotSyncer]
    func defaultConfigTriplet() -> ConfigTriplet
    func newEditableTriplet() -> EditableConfigTriplet
    func createXcodeServer(config: XcodeServerConfig) -> XcodeServer
    func createProject(config: ProjectConfig) -> Project
    func createSourceServer(token: String) -> GitHubServer
    func createTrigger(config: TriggerConfig) -> Trigger
}

public class SyncerFactory: SyncerFactoryType {
    
    private var syncerPool = [RefType: HDGitHubXCBotSyncer]()
    private var projectPool = [RefType: Project]()
    private var xcodeServerPool = [RefType: XcodeServer]()
    
    public init() { }
    
    private func createSyncer(triplet: ConfigTriplet) -> HDGitHubXCBotSyncer {
        
        let xcodeServer = self.createXcodeServer(triplet.server)
        let githubServer = self.createSourceServer(triplet.project.githubToken)
        let project = self.createProject(triplet.project)
        let triggers = triplet.triggers.map { self.createTrigger($0) }
        
        if let poolAttempt = self.syncerPool[triplet.syncer.id] {
            poolAttempt.config.value = triplet.syncer
            poolAttempt.xcodeServer.config = triplet.server
            poolAttempt.project.config.value = triplet.project
            poolAttempt.buildTemplate = triplet.buildTemplate
            poolAttempt.triggers = triggers
            return poolAttempt
        }
        
        let syncer = HDGitHubXCBotSyncer(
            integrationServer: xcodeServer,
            sourceServer: githubServer,
            project: project,
            buildTemplate: triplet.buildTemplate,
            triggers: triggers,
            config: triplet.syncer)
        
        self.syncerPool[triplet.syncer.id] = syncer
        
        //TADAAA
        return syncer
    }
    
    public func createSyncers(configs: [ConfigTriplet]) -> [HDGitHubXCBotSyncer] {
        
        //create syncers
        let created = configs.map { self.createSyncer($0) }
        
        let createdIds = Set(created.map { $0.config.value.id })
        
        //remove the syncers that haven't been created (deleted)
        let deleted = Set(self.syncerPool.keys).subtract(createdIds)
        deleted.forEach {
            self.syncerPool[$0]?.active = false
            self.syncerPool.removeValueForKey($0)
        }
        
        return created
    }
    
    public func defaultConfigTriplet() -> ConfigTriplet {
        return ConfigTriplet(syncer: SyncerConfig(), server: XcodeServerConfig(), project: ProjectConfig(), buildTemplate: BuildTemplate(), triggers: [])
    }
    
    public func newEditableTriplet() -> EditableConfigTriplet {
        return EditableConfigTriplet(syncer: SyncerConfig(), server: nil, project: nil, buildTemplate: nil, triggers: nil)
    }
    
    //sort of private
    public func createXcodeServer(config: XcodeServerConfig) -> XcodeServer {
        
        if let poolAttempt = self.xcodeServerPool[config.id] {
            poolAttempt.config = config
            return poolAttempt
        }

        let server = XcodeServerFactory.server(config)
        self.xcodeServerPool[config.id] = server
        
        return server
    }
    
    public func createProject(config: ProjectConfig) -> Project {
        
        if let poolAttempt = self.projectPool[config.id] {
            poolAttempt.config.value = config
            return poolAttempt
        }
        
        //TODO: maybe this producer SHOULD throw errors, when parsing fails?
        let project = try! Project(config: config)
        self.projectPool[config.id] = project
        
        return project
    }
    
    public func createSourceServer(token: String) -> GitHubServer {
        let server = GitHubFactory.server(token)
        return server
    }
    
    public func createTrigger(config: TriggerConfig) -> Trigger {
        let trigger = Trigger(config: config)
        return trigger
    }
}
