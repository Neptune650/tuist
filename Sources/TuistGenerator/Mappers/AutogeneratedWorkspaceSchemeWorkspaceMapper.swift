import Foundation
import TuistCore
import TuistGraph

/// Mapper that generates a new scheme `ProjectName-Workspace` that includes all targets from a given workspace
public final class AutogeneratedWorkspaceSchemeWorkspaceMapper: WorkspaceMapping { // swiftlint:disable:this type_name
    // MARK: - Init

    let forceWorkspaceSchemes: Bool

    public init(forceWorkspaceSchemes: Bool) {
        self.forceWorkspaceSchemes = forceWorkspaceSchemes
    }

    public func map(workspace: WorkspaceWithProjects) throws -> (WorkspaceWithProjects, [SideEffectDescriptor]) {
        guard workspace.workspace.generationOptions.autogeneratedWorkspaceSchemes != .disabled || forceWorkspaceSchemes,
              let project = workspace.projects.first
        else {
            return (workspace, [])
        }

        let platforms = Set(
            workspace.projects
                .flatMap {
                    $0.targets.map(\.platform)
                }
        )

        let schemes: [Scheme]

        if platforms.count == 1, let platform = platforms.first {
            schemes = [
                scheme(
                    name: "\(workspace.workspace.name)-Workspace",
                    platform: platform,
                    project: project,
                    workspace: workspace
                ),
            ]
        } else {
            schemes = platforms.map { platform in
                scheme(
                    name: "\(workspace.workspace.name)-Workspace-\(platform.caseValue)",
                    platform: platform,
                    project: project,
                    workspace: workspace
                )
            }
        }

        var workspace = workspace
        workspace.workspace.schemes.append(contentsOf: schemes)
        return (workspace, [])
    }

    // MARK: - Helpers

    private func scheme(
        name: String,
        platform: Platform,
        project: Project,
        workspace: WorkspaceWithProjects
    ) -> Scheme {
        let testingOptions = workspace.workspace.generationOptions.autogeneratedWorkspaceSchemes.testingOptions
        var (targets, testableTargets): ([TargetReference], [TestableTarget]) = workspace.projects
            .reduce(([], [])) { result, project in
                let targets = project.targets
                    .filter { $0.platform == platform }
                    .map { TargetReference(projectPath: project.path, name: $0.name) }
                let testableTargets = project.targets
                    .filter { $0.platform == platform }
                    .filter(\.product.testsBundle)
                    .map { TargetReference(projectPath: project.path, name: $0.name) }
                    .map {
                        TestableTarget(
                            target: $0,
                            parallelizable: testingOptions.contains(.parallelizable),
                            randomExecutionOrdering: testingOptions.contains(.randomExecutionOrdering)
                        )
                    }

                return (result.0 + targets, result.1 + testableTargets)
            }

        targets = targets.sorted(by: { $0.name < $1.name })
        testableTargets = testableTargets.sorted(by: { $0.target.name < $1.target.name })

        let coverageSettings = codeCoverageSettings(workspace: workspace)

        return Scheme(
            name: name,
            shared: true,
            buildAction: BuildAction(targets: targets),
            testAction: TestAction(
                targets: testableTargets,
                arguments: nil,
                configurationName: project.defaultDebugBuildConfigurationName,
                attachDebugger: true,
                coverage: coverageSettings.isEnabled,
                codeCoverageTargets: coverageSettings.targets,
                expandVariableFromTarget: nil,
                preActions: [],
                postActions: [],
                diagnosticsOptions: [.mainThreadChecker]
            )
        )
    }

    private func codeCoverageSettings(workspace: WorkspaceWithProjects) -> (isEnabled: Bool, targets: [TargetReference]) {
        let codeCoverageTargets = workspace.workspace.codeCoverageTargets(projects: workspace.projects)

        switch workspace.workspace.generationOptions.autogeneratedWorkspaceSchemes.codeCoverageMode {
        case .all: return (true, codeCoverageTargets)
        case .disabled: return (false, codeCoverageTargets)
        case .targets: return (true, codeCoverageTargets)
        case .relevant:
            return (!codeCoverageTargets.isEmpty, codeCoverageTargets)
        }
    }
}