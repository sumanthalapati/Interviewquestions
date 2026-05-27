# ☁️ Azure DevOps & CI/CD Interview Questions — Complete Guide

> A comprehensive reference covering Azure DevOps services, CI/CD pipelines, YAML deep dives, artifacts, security, testing, deployment strategies, Azure Boards, and GCP Cloud Storage integration.

---

## 📋 Table of Contents

1. [Azure DevOps Overview & Repos](#section-1--azure-devops-overview--repos)
2. [CI Pipelines](#section-2--ci-pipelines)
3. [CD & Multi-Stage Pipelines](#section-3--cd--multi-stage-pipelines)
4. [YAML Pipeline Deep Dive](#section-4--yaml-pipeline-deep-dive)
5. [Artifacts & Package Management](#section-5--artifacts--package-management)
6. [Pipeline Security & Secrets](#section-6--pipeline-security--secrets)
7. [Testing in Pipelines](#section-7--testing-in-pipelines)
8. [Deployment Strategies](#section-8--deployment-strategies)
9. [Azure Boards & Agile](#section-9--azure-boards--agile)
10. [GCP Cloud Storage Integration](#section-10--gcp-cloud-storage-integration)

---

## Section 1 — Azure DevOps Overview & Repos

### Q1. What are the five core services in Azure DevOps and how do they connect?

**Answer:** Azure DevOps provides five integrated services: **Boards** (Agile planning with Epics/Features/Stories), **Repos** (Git or TFVC source control), **Pipelines** (CI/CD automation), **Test Plans** (manual and exploratory testing), and **Artifacts** (package management for NuGet/npm/Maven). They connect through work item linking — commits reference AB#1234, PRs trigger Pipelines for build validation, pipeline test runs publish results to Test Plans, and build outputs are pushed to Artifacts feeds. This tight integration provides full traceability from a work item to a deployed artifact.

❌ **Violates:**
```yaml
# Treating services as isolated silos — no linking, no traceability
steps:
  - script: dotnet build
    # No work item reference, no artifact publish, no test results
```

✅ **Satisfies:**
```yaml
# CI pipeline linked to Boards + Artifacts + Test Plans
trigger:
  branches:
    include: [main, feature/*]

steps:
  - task: DotNetCoreCLI@2
    displayName: 'Build'
    inputs:
      command: build

  - task: DotNetCoreCLI@2
    displayName: 'Test'
    inputs:
      command: test
      arguments: '--logger trx'
      publishTestResults: true  # feeds Test Plans

  - task: PublishPipelineArtifact@1
    inputs:
      artifactName: 'drop'       # feeds Artifacts / CD pipeline
      targetPath: '$(Build.ArtifactStagingDirectory)'
```

---

### Q2. What is the difference between Azure Repos Git and TFVC, and what branch naming conventions are recommended?

**Answer:** Azure Repos Git is a distributed version control system where every developer has a full local copy of the repository, enabling offline work and flexible branching. TFVC (Team Foundation Version Control) is a centralized system where history lives on the server and checkouts are workspace-based. Git is the strongly recommended choice for modern teams due to its ecosystem, PR workflows, and compatibility with open-source tooling. Recommended branch naming follows the pattern `feature/`, `bugfix/`, `release/`, and `hotfix/` prefixes with descriptive names and optional work item IDs (e.g., `feature/1234-user-login`).

❌ **Violates:**
```yaml
# No branch naming policy — developers push directly with arbitrary names
branches:
  - dev2
  - johns-branch
  - fix
  - TEMP
```

✅ **Satisfies:**
```yaml
# Branch policy enforcing naming convention in Azure DevOps
# Set via UI or REST API — enforced pattern:
# feature/*    bugfix/*    release/*    hotfix/*    main

# Example branches:
# feature/1234-user-authentication
# bugfix/5678-null-reference-login
# release/2.4.0
# hotfix/9012-critical-payment-bug
```

---

### Q3. How does the Pull Request workflow work in Azure Repos, including PR templates, required reviewers, auto-complete, and build validation?

**Answer:** A Pull Request in Azure Repos is the mechanism for merging a feature branch into a target branch with enforced quality gates. PR templates (stored as `.azuredevops/pull_request_template.md`) pre-populate the PR description with a checklist. Required reviewer policies mandate specific individuals or groups approve before merge. Build validation automatically triggers a pipeline run against the PR's merged result. Auto-complete merges the PR as soon as all policies pass, preventing forgotten PRs.

❌ **Violates:**
```yaml
# No branch policies — direct push to main, no review, no build check
# Branch: main
# Protection: none
# Result: broken code ships to production
```

✅ **Satisfies:**
```markdown
<!-- .azuredevops/pull_request_template.md -->
## Description
<!-- What does this PR do? Link work item: AB#XXXX -->

## Checklist
- [ ] Unit tests added/updated
- [ ] No hardcoded secrets
- [ ] Reviewed SOLID principles
- [ ] Updated CHANGELOG
```

```yaml
# Branch policy (configured via Azure DevOps UI / REST API):
# - Require minimum 2 reviewers
# - Build validation: trigger CI pipeline on PR
# - Required reviewer: team-leads group
# - Auto-complete: enabled after all checks pass
# - Linked work item: required
```

---

### Q4. What are GitFlow, GitHub Flow, and Trunk-Based Development, and which works best for Continuous Delivery?

**Answer:** GitFlow uses long-lived `develop`, `release`, and `hotfix` branches alongside `main`, providing structure for release trains but creating merge complexity and slowing CI. GitHub Flow simplifies to `main` + short-lived feature branches with direct PR merges — good for teams deploying frequently. Trunk-Based Development has all developers commit to `main` (or very short-lived branches < 24 hours), relying on feature flags for incomplete work, and is the best fit for Continuous Delivery because it eliminates integration debt and keeps the build perpetually deployable.

❌ **Violates:**
```yaml
# GitFlow with long-lived develop branch — merge conflicts accumulate
branches:
  main:        # production only, rarely merged
  develop:     # long-lived, all features merged here
  feature/x:  # lives for weeks, diverges significantly
  release/1.2: # another long-lived branch
```

✅ **Satisfies:**
```yaml
# Trunk-Based Development with feature flags
branches:
  main:              # always deployable, CI runs on every commit
  feature/short:     # lives < 24-48 hours, small incremental changes

# Feature flag in code prevents incomplete features from exposing:
# if (featureManager.IsEnabled("NewCheckout")) { ... }
# Branch policy: require PR + build validation before merge to main
```

---

### Q5. What are Azure DevOps Service Connections, and what is the difference between project-scope and organization-scope?

**Answer:** Service Connections store credentials and endpoints that pipelines use to authenticate to external services like Azure subscriptions, GCP, Docker registries, and generic REST endpoints. Project-scoped connections are only accessible within the project they are created in, limiting blast radius if credentials are compromised. Organization-scoped connections can be shared across all projects in the org, useful for shared infrastructure teams but requiring stronger governance. Pipelines reference service connections by name in tasks without exposing the underlying secret.

❌ **Violates:**
```yaml
# Hardcoding credentials directly in pipeline — massive security risk
steps:
  - script: |
      az login --service-principal -u $(CLIENT_ID) -p "MyP@ssw0rd123" --tenant $(TENANT_ID)
      # Credential visible in logs, stored in YAML, leaked to contributors
```

✅ **Satisfies:**
```yaml
# Service connection defined in Azure DevOps UI (project scope)
# Pipeline references it by name — credentials never in YAML

steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'MyProject-Azure-Prod'   # service connection name
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        az webapp deploy --name myapp --resource-group myRG
```

---

### Q6. What are Azure DevOps Environments, and how do approval gates and exclusive locks work?

**Answer:** Environments are logical targets (Dev, Staging, Prod) that group resources (Kubernetes namespaces, Azure App Services) and provide deployment history, traceability, and governance. Pre-deployment approval gates require designated users/groups to manually approve before a stage deploys to that environment. Post-deployment checks validate the deployment succeeded. Exclusive lock prevents concurrent deployments to the same environment, ensuring only one pipeline run deploys at a time to avoid race conditions.

❌ **Violates:**
```yaml
# No environment, no approval — any pipeline run deploys straight to prod
stages:
  - stage: Deploy
    jobs:
      - job: DeployProd
        steps:
          - task: AzureWebApp@1
            inputs:
              appName: 'my-prod-app'
              # No approval, no audit trail, concurrent runs possible
```

✅ **Satisfies:**
```yaml
stages:
  - stage: DeployProd
    jobs:
      - deployment: DeployToProd
        environment: 'Production'         # environment with approval gate configured
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    azureSubscription: 'Prod-ServiceConnection'
                    appName: 'my-prod-app'

# In Azure DevOps UI on 'Production' environment:
# - Approvals: require 2 approvals from 'Release-Managers' group
# - Exclusive lock: enabled (no concurrent deployments)
# - Timeout: 1 hour to approve or auto-reject
```

---

### Q7. What are the Git authentication options in Azure Repos, and how do you prevent direct pushes to main?

**Answer:** Azure Repos supports PAT (Personal Access Token) for HTTPS authentication with configurable expiry and scope, and SSH keys for password-less authentication via key pairs stored in user profile settings. PATs should be short-lived and scoped to minimum required permissions. Sparse checkout (`--sparse`) downloads only specified directories, reducing checkout time for monorepos. Preventing direct pushes to `main` is achieved via Branch Policies: enable "Require a pull request before merging" which blocks all direct pushes.

❌ **Violates:**
```bash
# Using long-lived PAT with full org scope stored in plaintext
git remote set-url origin https://full-org-admin-PAT@dev.azure.com/org/project/_git/repo
# PAT never expires, has full access, stored in shell history
```

✅ **Satisfies:**
```bash
# SSH authentication — no token in URLs, key pair based
ssh-keygen -t ed25519 -C "ci-agent"
# Upload public key to Azure DevOps User Settings > SSH Keys

git remote set-url origin git@ssh.dev.azure.com:v3/org/project/repo

# Branch policy to block direct push to main (configured in UI):
# Repos > Branches > main > Branch Policies
# ✅ Require a pull request before merging
# ✅ Minimum number of reviewers: 2
# ✅ Block direct pushes: enabled
```

---

### Q8. What should a thorough code review check in Azure Repos PRs?

**Answer:** A thorough PR review covers correctness (logic errors, edge cases, null handling), security (no hardcoded secrets, input validation, SQL injection risks, proper auth checks), performance (N+1 queries, unnecessary allocations, missing indexes), test coverage (new behavior has unit tests, no trivial test names), and design quality (SOLID principles, appropriate abstractions, naming clarity). Azure DevOps supports comment types: active (must be resolved), resolved, and won't fix. PR policies can require all active comments be resolved before merge.

❌ **Violates:**
```csharp
// PR passes without reviewer catching:
public User GetUser(string id)
{
    var sql = $"SELECT * FROM Users WHERE Id = '{id}'"; // SQL injection
    return db.Query<User>(sql).FirstOrDefault();        // no null check
    // No unit test added, no error handling
}
```

✅ **Satisfies:**
```csharp
// Reviewer requests: parameterized query, null handling, test
public async Task<User?> GetUserAsync(int id)
{
    return await _db.Users
        .AsNoTracking()
        .FirstOrDefaultAsync(u => u.Id == id);  // EF parameterizes automatically
}

// PR comment: "Please add unit test for userId <= 0 edge case"
// PR policy: all active comments must be resolved before merge
```

---

### Q9. How do you link commits and PRs to Azure Boards work items, and how do work item states transition automatically?

**Answer:** Work items link to commits by including `AB#1234` in the commit message or PR title/description, where `1234` is the work item ID. Branch naming can also trigger auto-linking when branches follow `users/name/1234-description` pattern. When a PR is completed (merged), Azure DevOps can automatically transition the linked work item state — for example, from "Active" to "Resolved" — based on the configured transition in project settings. This provides full traceability from requirement to deployed code.

❌ **Violates:**
```bash
# Commit with no work item reference — no traceability
git commit -m "fix stuff"
git commit -m "update"
git commit -m "changes for john"
# Work items remain stale, no audit trail
```

✅ **Satisfies:**
```bash
# Commit message with work item link
git commit -m "feat: implement user authentication AB#1234"

# PR title includes work item
# "Feature: User Authentication [AB#1234]"

# Branch name for auto-link
git checkout -b feature/1234-user-authentication

# In Project Settings > Repositories > Work item transition:
# On PR complete: transition linked items to "Resolved"
# On PR merge to main: transition to "Closed"
```

---

### Q10. Azure DevOps vs GitHub Actions — feature comparison and when to choose each?

**Answer:** Azure DevOps is a full ALM (Application Lifecycle Management) platform with Boards, Repos, Pipelines, Test Plans, and Artifacts integrated into one product, making it ideal for enterprises needing tight project management + CI/CD in a single tool. GitHub Actions is tightly coupled to GitHub repos and offers a massive marketplace of community actions, better for open-source projects or teams already on GitHub. Azure DevOps excels at complex release management, approval workflows, and Azure-native integrations. Both can be cross-integrated — GitHub repos can trigger Azure Pipelines, and Azure DevOps work items can sync with GitHub issues.

❌ **Violates:**
```yaml
# Choosing GitHub Actions for an enterprise team with:
# - Complex multi-stage releases needing manual approvals
# - Azure Boards for sprint planning
# - Regulatory compliance requiring audit trails
# Result: managing two tools, losing traceability
```

✅ **Satisfies:**
```yaml
# Azure DevOps — enterprise team with full ALM needs
# Boards: sprint planning, capacity, burndown
# Repos: branch policies, PR workflows
# Pipelines: multi-stage with approval gates
# Test Plans: manual test case management
# Artifacts: private NuGet/npm feeds

# GitHub Actions — open-source .NET library
# Triggers on PR to GitHub repo
# Community actions: dotnet-build, codecov, nuget-push
# Simpler YAML, faster iteration for OSS contributors

# Cross-integration when needed:
# GitHub repo webhook → Azure Pipeline trigger
# Azure Boards + GitHub integration for issue linking
```

> 📚 Reference: [Azure DevOps Documentation](https://docs.microsoft.com/en-us/azure/devops/)
> 📚 Medium: [Azure DevOps vs GitHub Actions — Complete Comparison](https://medium.com/azure-devops-vs-github-actions)

---

## Section 2 — CI Pipelines

### Q11. What is Continuous Integration, and what does a minimal .NET 8 CI pipeline YAML look like?

**Answer:** Continuous Integration is the practice of automatically building and testing every code change committed to a shared repository, providing rapid feedback and catching integration errors early. A minimal .NET 8 CI pipeline runs on every push to main/feature branches and executes restore, build, test, and publish steps. The key principle is that the build must be fast (< 10 minutes ideally) and the `main` branch must always be in a deployable state after CI passes.

❌ **Violates:**
```yaml
# No CI — manual builds, no automated tests
# Developer runs "dotnet build" locally, deploys manually
# Integration errors discovered days later in production
trigger: none
steps:
  - script: echo "Build manually when ready"
```

✅ **Satisfies:**
```yaml
# Minimal .NET 8 CI pipeline
trigger:
  branches:
    include:
      - main
      - feature/*

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'

steps:
  - task: UseDotNet@2
    displayName: 'Use .NET 8'
    inputs:
      version: '8.x'

  - task: DotNetCoreCLI@2
    displayName: 'Restore'
    inputs:
      command: restore
      projects: '**/*.csproj'

  - task: DotNetCoreCLI@2
    displayName: 'Build'
    inputs:
      command: build
      arguments: '--no-restore --configuration $(buildConfiguration)'

  - task: DotNetCoreCLI@2
    displayName: 'Test'
    inputs:
      command: test
      arguments: '--no-build --configuration $(buildConfiguration) --logger trx'
      publishTestResults: true

  - task: DotNetCoreCLI@2
    displayName: 'Publish'
    inputs:
      command: publish
      arguments: '--no-build --configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)'

  - task: PublishPipelineArtifact@1
    displayName: 'Upload Artifact'
    inputs:
      artifactName: 'drop'
      targetPath: '$(Build.ArtifactStagingDirectory)'
```

---

### Q12. What are the different trigger types in Azure Pipelines?

**Answer:** Azure Pipelines supports four trigger types: CI triggers fire on branch pushes (with include/exclude filters), PR triggers fire when a pull request targets specified branches (can be disabled for draft PRs), scheduled triggers use cron syntax to run pipelines at fixed times (e.g., nightly builds), and pipeline resource triggers fire when another pipeline completes successfully (enabling chained CI/CD). Each trigger type serves a different purpose in the development lifecycle and can be combined in a single pipeline definition.

❌ **Violates:**
```yaml
# Only manual trigger — no automation, no CI feedback loop
trigger: none
pr: none
# Developers must manually queue builds, leading to integration delays
```

✅ **Satisfies:**
```yaml
# CI trigger — runs on push to main and feature branches
trigger:
  branches:
    include: [main, release/*]
    exclude: [experimental/*]
  paths:
    exclude: ['**/*.md', 'docs/**']  # skip docs-only changes

# PR trigger — runs on PRs targeting main
pr:
  branches:
    include: [main]
  drafts: false   # skip draft PRs

# Scheduled trigger — nightly full build at 2am UTC
schedules:
  - cron: '0 2 * * *'
    displayName: 'Nightly Build'
    branches:
      include: [main]
    always: true  # run even if no code changes

# Pipeline resource trigger — run CD when CI completes
resources:
  pipelines:
    - pipeline: CI
      source: 'MyApp-CI'
      trigger:
        branches: [main]
```

---

### Q13. What is the difference between Microsoft-hosted and self-hosted agents, and when do you need self-hosted?

**Answer:** Microsoft-hosted agents are ephemeral VMs provisioned fresh for each job from pools named `ubuntu-latest`, `windows-latest`, or `macos-latest`, with pre-installed tools and no maintenance overhead. Self-hosted agents are persistent machines (physical, VM, or container) you manage, running the Azure Pipelines agent software. You need self-hosted agents when builds require access to on-premises resources (databases, file shares), need specialized hardware (GPUs), have licensing restrictions, require faster builds via persistent caching, or need tools not available on hosted images.

❌ **Violates:**
```yaml
# Using hosted agent for pipeline that needs on-premises SQL Server
pool:
  vmImage: 'ubuntu-latest'
steps:
  - script: |
      sqlcmd -S 192.168.1.100 -d MyDb -Q "SELECT 1"
      # Fails — hosted agent has no network access to on-premises SQL
```

✅ **Satisfies:**
```yaml
# Self-hosted agent pool for on-premises access
pool:
  name: 'OnPremises-Agents'   # self-hosted pool with on-prem network access
  demands:
    - Agent.OS -equals Windows_NT
    - SqlServer -equals 2022    # custom capability set on agent

steps:
  - script: |
      sqlcmd -S $(OnPremSqlServer) -d $(DbName) -Q "SELECT 1"

# Self-hosted agent registration (one-time setup on the machine):
# 1. Download agent: https://dev.azure.com/{org}/_settings/agentpools
# 2. ./config.sh --url https://dev.azure.com/org --auth pat --token $(PAT)
# 3. ./run.sh  (or install as service)

# Hosted agent pool for standard CI:
pool:
  vmImage: 'ubuntu-latest'
```

---

### Q14. What are the complete .NET build steps in a production-quality CI pipeline?

**Answer:** A production-quality .NET pipeline uses `UseDotNet` to pin the SDK version, `restore` to fetch packages (enabling caching), `build --no-restore` to avoid double-restoring, `test` with TRX logger and code coverage collection, `publish` to produce the deployment artifact, and `PublishPipelineArtifact` to store the artifact for CD stages. The `--no-restore` and `--no-build` flags chain steps efficiently, preventing redundant work. Adding `--collect "XPlat Code Coverage"` and publishing coverage results provides visibility into test quality.

❌ **Violates:**
```yaml
# Inefficient pipeline — restores and builds multiple times
steps:
  - script: dotnet restore
  - script: dotnet build    # restores again internally
  - script: dotnet test     # builds again internally
  - script: dotnet publish  # builds again internally
  # 4x the restore/build time, no artifacts saved
```

✅ **Satisfies:**
```yaml
variables:
  buildConfiguration: 'Release'
  dotnetVersion: '8.x'

steps:
  - task: UseDotNet@2
    displayName: 'Pin .NET 8 SDK'
    inputs:
      version: '$(dotnetVersion)'
      includePreviewVersions: false

  - task: DotNetCoreCLI@2
    displayName: '01 Restore packages'
    inputs:
      command: restore
      projects: '**/*.csproj'
      feedsToUse: 'select'
      vstsFeed: 'MyProject/MyFeed'   # private Azure Artifacts feed

  - task: DotNetCoreCLI@2
    displayName: '02 Build (no-restore)'
    inputs:
      command: build
      projects: '**/*.csproj'
      arguments: '--no-restore --configuration $(buildConfiguration) /p:TreatWarningsAsErrors=true'

  - task: DotNetCoreCLI@2
    displayName: '03 Test (no-build) + Coverage'
    inputs:
      command: test
      projects: '**/*Tests.csproj'
      arguments: >
        --no-build
        --configuration $(buildConfiguration)
        --logger trx
        --collect "XPlat Code Coverage"
        -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura
      publishTestResults: true

  - task: DotNetCoreCLI@2
    displayName: '04 Publish (no-build)'
    inputs:
      command: publish
      projects: 'src/MyApp/MyApp.csproj'
      arguments: '--no-build --configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)/app'
      zipAfterPublish: true
      modifyOutputPath: false

  - task: PublishPipelineArtifact@1
    displayName: '05 Upload artifact'
    inputs:
      artifactName: 'webapp-$(Build.BuildNumber)'
      targetPath: '$(Build.ArtifactStagingDirectory)/app'
      publishLocation: 'pipeline'
```

---

### Q15. How do pipeline variables work in Azure Pipelines — predefined, custom, variable groups, and output variables?

**Answer:** Azure Pipelines provides predefined variables like `$(Build.BuildNumber)`, `$(Build.SourceBranchName)`, and `$(Agent.OS)` that are automatically populated. Custom variables are defined in the `variables:` section of YAML or in the pipeline UI. Variable groups are reusable collections of variables (optionally linked to Azure Key Vault) shared across pipelines. Output variables allow one step/job to pass values to subsequent steps/jobs using `##vso[task.setvariable]`. The three syntax forms — `$(var)` (macro, runtime), `${{ variables.var }}` (template expression, compile-time), and `$[variables.var]` (runtime expression) — serve different evaluation phases.

❌ **Violates:**
```yaml
# Hardcoded values everywhere — no reuse, no env separation
steps:
  - script: |
      az webapp deploy --name my-prod-app-hardcoded
      --resource-group rg-prod-hardcoded
      # Cannot reuse pipeline, no variable groups
```

✅ **Satisfies:**
```yaml
variables:
  # Custom pipeline variable
  buildConfiguration: 'Release'
  # Reference variable group (linked to Key Vault for secrets)
  - group: 'MyApp-Prod-Variables'

stages:
  - stage: Build
    variables:
      # Stage-scoped variable
      stageName: 'build'
    jobs:
      - job: CompileAndTest
        steps:
          # Using predefined variables
          - script: echo "Branch: $(Build.SourceBranchName), Build: $(Build.BuildNumber)"

          # Setting output variable
          - bash: |
              VERSION=$(cat version.txt)
              echo "##vso[task.setvariable variable=AppVersion;isOutput=true]$VERSION"
            name: setVersion

          # Compile-time template expression (evaluated before job runs)
          - script: echo "Config is ${{ variables.buildConfiguration }}"

          # Runtime expression
          - script: echo "Version $[dependencies.CompileAndTest.outputs['setVersion.AppVersion']]"
```

---

### Q16. How do you implement caching in Azure Pipelines to speed up builds?

**Answer:** The `Cache@2` task stores and restores directories between pipeline runs using a cache key — typically a hash of the lock file (packages.lock.json, package-lock.json). When the key matches a previous run's cache, the directory is restored from cache (cache hit), skipping the download step. `restoreKeys` provides fallback keys for partial cache hits, useful when the lock file changes but most packages are unchanged. Caching NuGet packages and npm node_modules are the most common use cases, typically saving 60-80% of restore time.

❌ **Violates:**
```yaml
# No caching — downloads all packages fresh every run
steps:
  - task: DotNetCoreCLI@2
    inputs:
      command: restore
  # Full restore every build: 2-5 minutes wasted each time
```

✅ **Satisfies:**
```yaml
variables:
  NUGET_PACKAGES: $(Pipeline.Workspace)/.nuget/packages
  NPM_CACHE: $(Pipeline.Workspace)/.npm

steps:
  # NuGet cache
  - task: Cache@2
    displayName: 'Cache NuGet packages'
    inputs:
      key: 'nuget | "$(Agent.OS)" | **/packages.lock.json,!**/bin/**'
      restoreKeys: |
        nuget | "$(Agent.OS)"
        nuget
      path: $(NUGET_PACKAGES)
      cacheHitVar: NUGET_CACHE_RESTORED

  - task: DotNetCoreCLI@2
    displayName: 'Restore (skip if cached)'
    condition: ne(variables.NUGET_CACHE_RESTORED, 'true')
    inputs:
      command: restore
      arguments: '--locked-mode'   # requires packages.lock.json

  # npm cache
  - task: Cache@2
    displayName: 'Cache npm packages'
    inputs:
      key: 'npm | "$(Agent.OS)" | ClientApp/package-lock.json'
      restoreKeys: |
        npm | "$(Agent.OS)"
      path: $(NPM_CACHE)

  - script: npm ci --cache $(NPM_CACHE)
    displayName: 'npm install (with cache)'
    workingDirectory: ClientApp
```

---

### Q17. How do parallel jobs and matrix strategies work in Azure Pipelines?

**Answer:** Jobs within a stage run in parallel by default unless `dependsOn` is specified to create a dependency chain. Matrix strategy spawns multiple copies of a job with different variable values (e.g., different .NET versions or OS), running them in parallel up to `maxParallel`. This enables testing across multiple framework/OS combinations without duplicating YAML. `dependsOn` with `condition: succeeded()` creates sequential gates — Test only runs if Build passes, Deploy only runs if Test passes.

❌ **Violates:**
```yaml
# Testing only one framework — misses multi-targeting regressions
jobs:
  - job: Test
    steps:
      - script: dotnet test --framework net8.0
      # Does not test net7.0 compatibility, ships broken NuGet package
```

✅ **Satisfies:**
```yaml
stages:
  - stage: Build
    jobs:
      - job: Compile
        steps:
          - task: DotNetCoreCLI@2
            inputs:
              command: build

  - stage: Test
    dependsOn: Build
    condition: succeeded()
    jobs:
      # Matrix: test .NET 7 + .NET 8 on Windows + Linux = 4 parallel jobs
      - job: CrossPlatformTests
        strategy:
          matrix:
            Net8_Linux:
              dotnetVersion: '8.x'
              vmImage: 'ubuntu-latest'
            Net8_Windows:
              dotnetVersion: '8.x'
              vmImage: 'windows-latest'
            Net7_Linux:
              dotnetVersion: '7.x'
              vmImage: 'ubuntu-latest'
            Net7_Windows:
              dotnetVersion: '7.x'
              vmImage: 'windows-latest'
          maxParallel: 4
        pool:
          vmImage: $(vmImage)
        steps:
          - task: UseDotNet@2
            inputs:
              version: $(dotnetVersion)
          - task: DotNetCoreCLI@2
            inputs:
              command: test
              arguments: '--framework net$(dotnetVersion | split(".")[0]).0'
```

---

### Q18. How do pipeline artifacts work — PublishPipelineArtifact vs PublishBuildArtifacts, and how are they consumed in CD?

**Answer:** `PublishPipelineArtifact@1` is the modern task that stores artifacts in the pipeline's artifact store with better performance and supports immutable references by build number. `PublishBuildArtifacts@1` is the legacy task that stores to Azure DevOps' server or a file share. In CD stages/pipelines, `DownloadPipelineArtifact@2` retrieves artifacts by name from the current or a specific pipeline run. Artifact retention policies control how long artifacts are kept — shorter for PR builds, longer for release builds — to manage storage costs.

❌ **Violates:**
```yaml
# Legacy task, no artifact in CD — manually copying files
- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: 'bin/'
    # Old task, slower, less reliable
# CD stage must re-build instead of using CI artifact
```

✅ **Satisfies:**
```yaml
# CI Pipeline — publish artifact
- task: PublishPipelineArtifact@1
  displayName: 'Publish web app artifact'
  inputs:
    artifactName: 'webapp'
    targetPath: '$(Build.ArtifactStagingDirectory)'
    publishLocation: 'pipeline'

# CD Stage (same or different pipeline) — download artifact
- task: DownloadPipelineArtifact@2
  displayName: 'Download webapp artifact'
  inputs:
    artifactName: 'webapp'
    targetPath: '$(Pipeline.Workspace)/webapp'
    # For cross-pipeline: specify buildType: specific, pipelineId, buildId

- task: AzureWebApp@1
  inputs:
    appName: 'my-webapp'
    package: '$(Pipeline.Workspace)/webapp/**/*.zip'

# Retention policy (set via UI or REST):
# PR builds: keep 10 days
# CI builds: keep 30 days
# Release builds: keep 1 year
```

---

### Q19. How do you configure build numbering with date-based patterns and GitVersion for SemVer?

**Answer:** Azure Pipelines uses the `name:` field at the pipeline level to define the build number format. The pattern `$(Date:yyyyMMdd).$(Rev:r)` generates numbers like `20241215.3` (third build on that date). GitVersion is a tool that inspects Git history and tags to automatically calculate a semantic version (MAJOR.MINOR.PATCH) based on branch names, commit messages, and tags. It integrates into pipelines via the `gitversion/execute` task and exposes variables like `$(GitVersion.SemVer)`.

❌ **Violates:**
```yaml
# Default build number: sequential integers with no meaning
# BuildNumber: 42, 43, 44 — no date, no version info
# Cannot tell when a build happened or what version it represents
name: $(Rev:r)
```

✅ **Satisfies:**
```yaml
# Date-based build number
name: $(Date:yyyyMMdd).$(Rev:r)
# Result: 20241215.1, 20241215.2, 20241216.1

# GitVersion for SemVer (install GitVersion globally or use task)
# GitVersion.yml in repo root:
# mode: Mainline
# branches:
#   main:
#     tag: ''
#   feature:
#     tag: alpha

steps:
  - task: gitversion/setup@0
    displayName: 'Install GitVersion'
    inputs:
      versionSpec: '5.x'

  - task: gitversion/execute@0
    displayName: 'Calculate SemVer'
    inputs:
      useConfigFile: true
      configFilePath: 'GitVersion.yml'

  # Now use variables: $(GitVersion.SemVer) = "2.3.1"
  - script: |
      echo "Version: $(GitVersion.SemVer)"
      dotnet pack --configuration Release /p:Version=$(GitVersion.SemVer)
```

---

### Q20. How do you diagnose and fix a failing CI pipeline with test failures, coverage threshold, and SonarQube quality gate?

**Answer:** When a pipeline fails, first check the job logs for the failing step — red steps expand to show stderr output. Test failures appear in the Tests tab with detailed failure messages and stack traces. Coverage threshold failures appear in the code coverage summary; fix by adding missing tests. SonarQube quality gate failures block the pipeline at the "SonarQube Analyze" step — check the SonarQube dashboard for which rules failed (new bugs, code smells, coverage drop, duplications). Fix each issue in sequence: tests first, then SonarQube issues, then re-push.

❌ **Violates:**
```yaml
# No test results published, no coverage, no quality gate
# Pipeline passes even with failing tests if using 'script:' directly
steps:
  - script: dotnet test || true   # swallowing test failures!
  # Pipeline always green, broken code ships
```

✅ **Satisfies:**
```yaml
steps:
  - task: DotNetCoreCLI@2
    displayName: 'Run Tests'
    inputs:
      command: test
      arguments: >
        --logger trx
        --collect "XPlat Code Coverage"
        /p:CoverletOutputFormat=opencover
      publishTestResults: true
      failTaskOnFailedTests: true    # fail pipeline on test failure

  - task: reportgenerator@5
    inputs:
      reports: '$(Agent.TempDirectory)/**/coverage.opencover.xml'
      targetdir: '$(Build.ArtifactStagingDirectory)/coverage'
      reporttypes: 'HtmlInline_AzurePipelines;Cobertura'

  - task: PublishCodeCoverageResults@2
    inputs:
      summaryFileLocation: '$(Build.ArtifactStagingDirectory)/coverage/Cobertura.xml'
      failIfCoverageEmpty: true

  # SonarQube quality gate
  - task: SonarQubePrepare@5
    inputs:
      SonarQube: 'SonarQube-Connection'
      scannerMode: 'MSBuild'
      projectKey: 'myproject'
      extraProperties: |
        sonar.coverage.exclusions=**/*Tests*/**
        sonar.cs.opencover.reportsPaths=$(Agent.TempDirectory)/**/coverage.opencover.xml

  - task: DotNetCoreCLI@2
    inputs:
      command: build

  - task: SonarQubeAnalyze@5

  - task: SonarQubePublish@5
    inputs:
      pollingTimeoutSec: '300'
      # Fails pipeline if quality gate status is ERROR
```

> 📚 Reference: [Azure Pipelines YAML Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
> 📚 Medium: [Building Production-Quality CI Pipelines with Azure DevOps](https://medium.com/ci-pipelines-azure-devops)

---

## Section 3 — CD & Multi-Stage Pipelines

### Q21. What is the difference between CI, CD (Continuous Delivery), and Continuous Deployment?

**Answer:** Continuous Integration (CI) automatically builds and tests every commit, catching integration errors immediately. Continuous Delivery (CD) extends CI by automating deployment to staging/pre-production environments, ensuring the software is always in a releasable state — but the final production push is a manual decision. Continuous Deployment goes one step further: every commit that passes all automated tests is automatically deployed to production with no manual intervention. The key differentiator is test confidence — Continuous Deployment requires extremely high confidence in automated tests, feature flags for incomplete work, and strong monitoring for rapid rollback.

❌ **Violates:**
```yaml
# Claiming "Continuous Deployment" but requiring manual production approval
# This is Continuous Delivery, not Continuous Deployment
stages:
  - stage: Deploy_Prod
    jobs:
      - deployment: Prod
        environment: 'Production'   # has manual approval gate
        # Manual approval = Continuous Delivery, not Continuous Deployment
```

✅ **Satisfies:**
```yaml
# Continuous Delivery: automated to staging, manual approval for prod
stages:
  - stage: Deploy_Staging
    dependsOn: CI
    jobs:
      - deployment: Staging
        environment: 'Staging'      # no approval gate
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1

  - stage: Deploy_Prod
    dependsOn: Deploy_Staging
    jobs:
      - deployment: Production
        environment: 'Production'   # approval gate here = Continuous Delivery

# Continuous Deployment: remove approval gate, add automated smoke tests + monitors
  - stage: Deploy_Prod_Automated
    dependsOn: Deploy_Staging
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: Production
        environment: 'Production-Auto'  # no approval gate
        # Relies on: extensive test suite + feature flags + Azure Monitor rollback
```

---

### Q22. How do you structure a multi-stage YAML pipeline with Build, Test, Dev, Staging, and Prod stages?

**Answer:** Multi-stage pipelines define stages with `dependsOn` to control sequencing and `condition` to control whether a stage runs. Each stage can target a different environment with different approval policies. The pattern is: Build (compile + artifact) → Test (integration tests against artifact) → DeployDev (always deploy) → DeployStagig (deploy on main branch) → DeployProd (deploy with approval, main branch only). Using `condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))` restricts production deployments to the main branch.

❌ **Violates:**
```yaml
# No stages — single flat job deploys directly to prod after build
jobs:
  - job: BuildAndDeploy
    steps:
      - script: dotnet build
      - task: AzureWebApp@1
        inputs:
          appName: 'my-prod-app'
      # No test stage, no dev/staging, no approval
```

✅ **Satisfies:**
```yaml
stages:
  - stage: Build
    displayName: 'Build & Package'
    jobs:
      - job: Compile
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: DotNetCoreCLI@2
            inputs: { command: build }
          - task: PublishPipelineArtifact@1
            inputs: { artifactName: 'drop', targetPath: '$(Build.ArtifactStagingDirectory)' }

  - stage: Test
    displayName: 'Integration Tests'
    dependsOn: Build
    condition: succeeded()
    jobs:
      - job: IntegrationTest
        steps:
          - task: DownloadPipelineArtifact@2
            inputs: { artifactName: 'drop' }
          - script: dotnet test tests/Integration.Tests.csproj

  - stage: DeployDev
    displayName: 'Deploy → Dev'
    dependsOn: Test
    condition: succeeded()
    jobs:
      - deployment: Dev
        environment: 'Dev'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs: { appName: 'myapp-dev', azureSubscription: 'Dev-SC' }

  - stage: DeployStaging
    displayName: 'Deploy → Staging'
    dependsOn: DeployDev
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: Staging
        environment: 'Staging'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs: { appName: 'myapp-staging', azureSubscription: 'Staging-SC' }

  - stage: DeployProd
    displayName: 'Deploy → Production'
    dependsOn: DeployStaging
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: Production
        environment: 'Production'    # manual approval gate configured in environment
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs: { appName: 'myapp-prod', azureSubscription: 'Prod-SC' }
```

---

### Q23. What are deployment jobs in Azure Pipelines and how do runOnce, rolling, and canary strategies differ?

**Answer:** Deployment jobs (using `- deployment:` syntax) are specialized jobs that target an environment and track deployment history. Unlike regular jobs, they record which version was deployed where and integrate with environment approval gates. `runOnce` deploys to all targets once — the simplest strategy for single-instance apps. `rolling` updates targets in batches, keeping some instances running during deployment. `canary` splits traffic by percentage (5%, 50%, 100%) with validation between increments, allowing rapid rollback if metrics degrade.

❌ **Violates:**
```yaml
# Regular job used for deployment — no environment tracking, no deployment history
jobs:
  - job: Deploy
    steps:
      - task: AzureWebApp@1
        inputs:
          appName: 'myapp'
      # No deployment record, no approval, no history
```

✅ **Satisfies:**
```yaml
jobs:
  # runOnce: simple single-target deployment
  - deployment: DeployRunOnce
    environment: 'Staging'
    strategy:
      runOnce:
        deploy:
          steps:
            - task: AzureWebApp@1

  # rolling: update 25% of instances at a time
  - deployment: DeployRolling
    environment: 'Production'
    strategy:
      rolling:
        maxParallel: 25%
        deploy:
          steps:
            - task: AzureWebApp@1
        on:
          failure:
            steps:
              - script: echo "Rolling back batch"

  # canary: 10% → validate → 100%
  - deployment: DeployCanary
    environment: 'Production'
    strategy:
      canary:
        increments: [10, 100]
        deploy:
          steps:
            - task: AzureWebApp@1
        postRouteTraffic:
          steps:
            - script: ./smoke-test.sh  # validate before next increment
        on:
          failure:
            steps:
              - script: ./rollback.sh
```

---

### Q24. How do pre-deployment and post-deployment approval gates work in Azure Pipelines?

**Answer:** Approval gates are configured on Environments in Azure DevOps — not in YAML directly. Pre-deployment approvals block a stage from starting until designated approvers click "Approve" in the Azure DevOps UI or respond to an email/Teams notification. Post-deployment approvals block the next stage until approvers confirm the deployment succeeded. A timeout can be configured to auto-reject if no response is received. Multiple approvers can be required, and approval order (sequential vs any) is configurable.

❌ **Violates:**
```yaml
# No approval — every push to main auto-deploys to production
stages:
  - stage: Prod
    jobs:
      - deployment: Prod
        environment: 'Production-NoApproval'
        # Missing approval gate: incidents from untested hotfixes go to prod immediately
```

✅ **Satisfies:**
```yaml
# YAML references the environment — approval is configured IN the environment
stages:
  - stage: DeployProd
    jobs:
      - deployment: DeployToProd
        environment: 'Production'    # this environment has approvals configured
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    appName: 'myapp-prod'

# Azure DevOps UI configuration for 'Production' environment:
# Approvals and checks > Add > Approvals
# - Approvers: Release-Managers group
# - Allow approvers to approve their own runs: No
# - Approval timeout: 24 hours (auto-reject after)
# - Instructions: "Verify staging smoke tests passed before approving"

# Post-deployment: configure on next environment's pre-deployment
# or use Release Gates (Azure Monitor, REST API) for automated checks
```

---

### Q25. What are Release Gates in Azure Pipelines and how do you configure them?

**Answer:** Release Gates are automated checks that run on a polling interval between pipeline stages, blocking progression until conditions are met. Types include Azure Monitor alerts (block if active alert exists), REST API gates (call any endpoint and evaluate JSON response), Azure Policy compliance, Work Item Query (block if critical bugs exist), and Azure Function/Logic App gates for custom logic. Gates have a minimum sampling duration (e.g., 10 minutes) and polling interval, ensuring conditions are stable before proceeding — not just momentarily passing.

❌ **Violates:**
```yaml
# No gates — deploying to prod without checking if staging is healthy
stages:
  - stage: Prod
    dependsOn: Staging
    condition: succeeded()
    # No check that Staging error rate is acceptable
    # No check that active P1 bugs exist
```

✅ **Satisfies:**
```yaml
# Gates are configured in Azure DevOps Environments UI, not YAML
# But the deployment job references the environment:

jobs:
  - deployment: DeployToProd
    environment: 'Production'   # environment has gates configured:
    # Gate 1: Azure Monitor — query for active critical alerts on staging
    #   Success criteria: alertsCount == 0
    #   Sampling interval: 5 minutes
    #   Minimum sampling duration: 10 minutes
    #
    # Gate 2: REST API gate — call health check endpoint
    #   URL: https://myapp-staging.azurewebsites.net/health
    #   Success criteria: response.status == "Healthy"
    #
    # Gate 3: Work Item Query — active P1 bugs
    #   Query: [Work Item Type] = Bug AND [Severity] = 1 AND [State] != Closed
    #   Success criteria: count == 0
    strategy:
      runOnce:
        deploy:
          steps:
            - task: AzureWebApp@1
```

---

### Q26. How do you deploy a .NET application to Azure App Service with slot swap for zero-downtime deployment?

**Answer:** Zero-downtime deployments to Azure App Service use deployment slots: the app is deployed to a staging slot (which runs on a separate URL), smoke tests validate the new version, and then a slot swap instantly redirects production traffic to the new version without downtime. The previous production slot remains warm as a swap target for immediate rollback. The `AzureWebApp@1` task deploys to the slot, and `AzureAppServiceManage@0` performs the swap.

❌ **Violates:**
```yaml
# Deploying directly to production slot — causes downtime and no rollback
- task: AzureWebApp@1
  inputs:
    azureSubscription: 'Prod-SC'
    appName: 'myapp-prod'
    package: '$(Pipeline.Workspace)/drop/**/*.zip'
    # Direct slot deployment causes cold start and brief unavailability
```

✅ **Satisfies:**
```yaml
steps:
  - task: DownloadPipelineArtifact@2
    inputs:
      artifactName: 'webapp'
      targetPath: '$(Pipeline.Workspace)/webapp'

  # Step 1: Deploy to staging slot (not production)
  - task: AzureWebApp@1
    displayName: 'Deploy to Staging Slot'
    inputs:
      azureSubscription: 'Prod-ServiceConnection'
      appType: 'webApp'
      appName: 'myapp-prod'
      deployToSlotOrASE: true
      resourceGroupName: 'rg-production'
      slotName: 'staging'           # deploy here first
      package: '$(Pipeline.Workspace)/webapp/**/*.zip'

  # Step 2: Smoke test the staging slot
  - task: PowerShell@2
    displayName: 'Smoke Test Staging Slot'
    inputs:
      targetType: inline
      script: |
        $response = Invoke-WebRequest -Uri "https://myapp-prod-staging.azurewebsites.net/health" -UseBasicParsing
        if ($response.StatusCode -ne 200) { throw "Smoke test failed: $($response.StatusCode)" }
        Write-Host "Smoke test passed"

  # Step 3: Swap staging → production (instant, zero downtime)
  - task: AzureAppServiceManage@0
    displayName: 'Swap Slots (Staging → Production)'
    inputs:
      azureSubscription: 'Prod-ServiceConnection'
      Action: 'Swap Slots'
      WebAppName: 'myapp-prod'
      ResourceGroupName: 'rg-production'
      SourceSlot: 'staging'
      SwapWithProduction: true
      # Previous production is now in staging slot — instant rollback available
```

---

### Q27. How do you manage environment-specific configuration using variable groups and Azure Key Vault?

**Answer:** Variable groups linked to Azure Key Vault allow pipeline stages to consume secrets without storing them in YAML or pipeline variables. Each environment (Dev, Staging, Prod) has its own variable group referencing the appropriate Key Vault. The pipeline service principal needs `Key Vault Secrets User` role on the Key Vault. In YAML, variable groups are declared at the stage level so each stage uses its environment-specific secrets. `FileTransform` task applies the variables to `appsettings.json` files during deployment.

❌ **Violates:**
```yaml
# Hardcoded connection strings in YAML — stored in Git, visible to all contributors
variables:
  DB_CONNECTION: 'Server=prod-sql;Password=MyP@ssw0rd123;Database=ProdDb'
  API_KEY: 'sk-1234567890abcdef'
# Secrets committed to repo history permanently
```

✅ **Satisfies:**
```yaml
stages:
  - stage: DeployStaging
    variables:
      - group: 'MyApp-Staging-Secrets'    # variable group linked to staging Key Vault
      - name: environmentName
        value: 'Staging'
    jobs:
      - deployment: Staging
        environment: 'Staging'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadPipelineArtifact@2
                  inputs: { artifactName: 'webapp' }

                # Replace tokens in appsettings with variable group values
                - task: FileTransform@1
                  inputs:
                    folderPath: '$(Pipeline.Workspace)/webapp'
                    fileType: json
                    targetFiles: '**/appsettings.json'
                  # Variables from group: ConnectionStrings__Default, ApiKey

                - task: AzureWebApp@1
                  inputs:
                    appName: 'myapp-staging'
                    package: '$(Pipeline.Workspace)/webapp/**/*.zip'

  - stage: DeployProd
    variables:
      - group: 'MyApp-Prod-Secrets'       # separate group for prod Key Vault
    jobs:
      - deployment: Production
        environment: 'Production'
```

---

### Q28. How do you handle database migrations in a CD pipeline?

**Answer:** Running database migrations in CD requires a backward-compatible strategy: the migration must be deployed before the new application code, and the migration must be compatible with both the old and new application versions (expand/contract pattern). In a .NET pipeline, EF Core migrations run via `dotnet ef database update` or by running the published migration bundle. The pipeline runs migrations first (in a pre-deployment step), validates success, then deploys the application. If migration fails, the deployment is aborted and the database remains in its previous state.

❌ **Violates:**
```yaml
# Deploying app and running migrations simultaneously — race condition
steps:
  - task: AzureWebApp@1
    inputs:
      appName: 'myapp'
  - script: dotnet ef database update
  # App starts with new code while DB still has old schema = errors
```

✅ **Satisfies:**
```yaml
steps:
  - task: DownloadPipelineArtifact@2
    inputs:
      artifactName: 'migrations'   # migration bundle published in CI

  # Step 1: Run migrations BEFORE deploying app
  - task: AzureKeyVault@2
    inputs:
      azureSubscription: 'Prod-SC'
      KeyVaultName: 'myapp-prod-kv'
      SecretsFilter: 'DbConnectionString'

  - task: PowerShell@2
    displayName: 'Run EF Core Migrations'
    inputs:
      targetType: inline
      script: |
        # Use migration bundle (no SDK needed on server)
        ./efbundle --connection "$(DbConnectionString)"
        if ($LASTEXITCODE -ne 0) { throw "Migration failed — aborting deployment" }

  # Step 2: Deploy app AFTER migration succeeds
  - task: AzureWebApp@1
    displayName: 'Deploy Application'
    inputs:
      appName: 'myapp-prod'
      package: '$(Pipeline.Workspace)/webapp/**/*.zip'

# CI: publish migration bundle
# - task: DotNetCoreCLI@2
#   inputs:
#     command: custom
#     custom: ef
#     arguments: >
#       migrations bundle
#       --project src/MyApp.Data
#       --startup-project src/MyApp.Api
#       --output $(Build.ArtifactStagingDirectory)/migrations/efbundle
#       --self-contained
```

---

### Q29. What rollback strategies are available in Azure DevOps CD pipelines?

**Answer:** Rollback options in Azure DevOps include: manual re-run of a previous pipeline build (targeting the last-known-good artifact), slot swap reversal for Azure App Service (swap staging back to production in seconds), automated rollback triggered by post-deployment Azure Monitor gates when error rate exceeds threshold, and pipeline-level rollback jobs in the `on: failure:` block of deployment strategies. The fastest rollback for App Service is slot swap reversal. Automated rollback requires pre-configured Azure Monitor alerts and a pipeline that monitors them post-deployment.

❌ **Violates:**
```yaml
# No rollback plan — deployment failure means manual intervention and downtime
stages:
  - stage: Deploy
    jobs:
      - deployment: Prod
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
        # No on.failure handler, no slot swap, no previous version available
```

✅ **Satisfies:**
```yaml
jobs:
  - deployment: DeployProd
    environment: 'Production'
    strategy:
      runOnce:
        deploy:
          steps:
            - task: AzureWebApp@1
              displayName: 'Deploy to Staging Slot'
              inputs:
                appName: 'myapp-prod'
                deployToSlotOrASE: true
                slotName: 'staging'

            - task: AzureAppServiceManage@0
              displayName: 'Swap to Production'
              inputs:
                Action: 'Swap Slots'
                WebAppName: 'myapp-prod'
                SourceSlot: 'staging'
                SwapWithProduction: true

            - task: PowerShell@2
              displayName: 'Post-Swap Smoke Test'
              inputs:
                targetType: inline
                script: |
                  Start-Sleep -Seconds 30  # warm up
                  $r = Invoke-WebRequest -Uri "https://myapp-prod.azurewebsites.net/health"
                  if ($r.StatusCode -ne 200) {
                    Write-Host "##vso[task.logissue type=error]Smoke test failed — triggering rollback"
                    exit 1
                  }

        on:
          failure:
            steps:
              - task: AzureAppServiceManage@0
                displayName: 'ROLLBACK: Swap Back'
                inputs:
                  Action: 'Swap Slots'
                  WebAppName: 'myapp-prod'
                  SourceSlot: 'staging'    # swap staging (broken) back to production (good)
                  SwapWithProduction: true
```

---

### Q30. What is Pipeline as Code and why is it preferred over Classic Release pipelines?

**Answer:** Pipeline as Code stores the CI/CD definition as YAML files in the source repository, making it subject to the same code review, versioning, and branch policies as application code. Classic release pipelines store configuration in Azure DevOps' database, making changes hard to review, audit, or roll back. YAML pipelines prevent configuration drift (the pipeline matches what is in the branch), enable PR reviews of pipeline changes, support templates for DRY reuse, and work with multi-stage deployments in a single file. Microsoft has deprecated Classic pipelines for new projects.

❌ **Violates:**
```yaml
# Classic release pipeline: defined in UI only, not in code
# - Pipeline changes are not tracked in Git
# - No PR review for pipeline modifications
# - Cannot test pipeline changes on a branch
# - Configuration can diverge from what teams expect
# - No template/reuse mechanism
# Result: "snowflake" pipelines that nobody understands
```

✅ **Satisfies:**
```yaml
# YAML pipeline stored in azure-pipelines.yml at repo root
# Changes require PR + code review before merging to main

# azure-pipelines.yml (versioned in Git)
trigger:
  branches:
    include: [main, feature/*]

# Template reference — DRY, shared across projects
extends:
  template: templates/dotnet-pipeline.yml@pipeline-templates
  parameters:
    appName: 'myapp'
    environments:
      - name: Dev
        serviceConnection: 'Dev-SC'
      - name: Staging
        serviceConnection: 'Staging-SC'
        approvalRequired: false
      - name: Production
        serviceConnection: 'Prod-SC'
        approvalRequired: true

# Benefits:
# - Pipeline change goes through PR review
# - git blame shows who changed what and when
# - Branch-specific pipelines for experimentation
# - Templates enforce org standards (security scans, etc.)
```

> 📚 Reference: [Multi-stage Pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/stages)
> 📚 Medium: [Zero-Downtime Deployments with Azure DevOps and App Service Slots](https://medium.com/zero-downtime-azure-devops)

---

## Section 4 — YAML Pipeline Deep Dive

### Q31. What is the full YAML hierarchy in Azure Pipelines?

**Answer:** An Azure Pipeline YAML file has a hierarchical structure: top-level keys (`trigger`, `pr`, `schedules`, `pool`, `variables`, `name`) define pipeline-wide settings, `stages` contain groups of related `jobs`, `jobs` contain `steps` (the actual work), and `deployment` jobs are specialized for environment targeting. Each level can override `pool` and `variables` from the parent. Understanding this hierarchy is essential for writing modular, efficient pipelines that correctly scope resources and variables to where they are needed.

❌ **Violates:**
```yaml
# Flat structure — everything in one job, no stages, hard to extend
steps:
  - script: dotnet build
  - script: dotnet test
  - task: AzureWebApp@1
  # Cannot add approvals, environments, parallel jobs, or reusable templates
```

✅ **Satisfies:**
```yaml
# Full annotated YAML hierarchy
name: $(Date:yyyyMMdd).$(Rev:r)    # pipeline-level build number format

trigger:                            # when to run CI
  branches:
    include: [main, feature/*]

pr:                                 # when to run PR validation
  branches:
    include: [main]

variables:                          # pipeline-level variables
  buildConfiguration: 'Release'
  - group: 'SharedSecrets'

pool:                               # default pool (overridable per job)
  vmImage: 'ubuntu-latest'

stages:
  - stage: Build                    # logical grouping of jobs
    displayName: 'Build and Test'
    variables:                      # stage-level variables
      stageVar: 'build-value'
    jobs:
      - job: Compile                # regular job (no environment)
        displayName: 'Compile .NET'
        timeoutInMinutes: 30
        pool:                       # job-level pool override
          vmImage: 'windows-latest'
        variables:                  # job-level variables
          jobVar: 'compile-value'
        steps:                      # ordered list of tasks/scripts
          - checkout: self
            fetchDepth: 1
          - task: UseDotNet@2       # task step
            inputs:
              version: '8.x'
          - script: dotnet build    # inline script step
            displayName: 'Build'

      - deployment: DeployDev       # deployment job (targets environment)
        dependsOn: Compile
        environment: 'Dev'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
```

---

### Q32. How do YAML templates work in Azure Pipelines for DRY, reusable pipelines?

**Answer:** Templates allow extracting step, job, or stage blocks into separate YAML files with parameters, enabling reuse across multiple pipelines without duplication. Step templates replace a list of steps, job templates replace entire jobs, and stage templates replace entire stages. Parameters declared with `name`, `type`, `default`, and `values` make templates configurable. The `@self` syntax references files in the current repository; `@repo-alias` references files from another repository declared under `resources.repositories`.

❌ **Violates:**
```yaml
# Copy-paste same build steps in every pipeline — drift and maintenance nightmare
# pipeline-a.yml and pipeline-b.yml both contain identical 30-line build block
# When dotnet version changes, must update 15 pipelines separately
```

✅ **Satisfies:**
```yaml
# templates/steps/dotnet-build.yml (shared template)
parameters:
  - name: buildConfiguration
    type: string
    default: 'Release'
  - name: dotnetVersion
    type: string
    default: '8.x'
  - name: runTests
    type: boolean
    default: true

steps:
  - task: UseDotNet@2
    inputs:
      version: ${{ parameters.dotnetVersion }}
  - task: DotNetCoreCLI@2
    inputs:
      command: restore
  - task: DotNetCoreCLI@2
    inputs:
      command: build
      arguments: '--no-restore --configuration ${{ parameters.buildConfiguration }}'
  - ${{ if eq(parameters.runTests, true) }}:
    - task: DotNetCoreCLI@2
      inputs:
        command: test
        publishTestResults: true
```

```yaml
# azure-pipelines.yml (consuming pipeline)
resources:
  repositories:
    - repository: templates
      type: git
      name: MyProject/pipeline-templates
      ref: refs/heads/main

stages:
  - stage: Build
    jobs:
      - job: Compile
        steps:
          # Reference step template from templates repo
          - template: templates/steps/dotnet-build.yml@templates
            parameters:
              buildConfiguration: 'Release'
              dotnetVersion: '8.x'
              runTests: true
```

---

### Q33. How do expressions and conditions work in Azure Pipelines YAML?

**Answer:** Conditions control whether a step, job, or stage executes. Built-in conditions include `succeeded()`, `failed()`, `always()`, and `succeededOrFailed()`. Custom conditions use expression functions like `eq()`, `ne()`, `and()`, `or()`, `contains()`, and `startsWith()`. Compile-time `${{ if }}` expressions are evaluated when the pipeline is compiled (before any step runs), enabling conditional inclusion of entire template blocks. Runtime conditions in `condition:` fields are evaluated when the agent picks up the job.

❌ **Violates:**
```yaml
# Deploying to prod from any branch — feature branches can deploy to production
- stage: DeployProd
  jobs:
    - deployment: Prod
      environment: 'Production'
      # No condition — feature/xyz branch could accidentally deploy to prod
```

✅ **Satisfies:**
```yaml
stages:
  - stage: DeployProd
    # Runtime condition: only deploy to prod from main branch after staging succeeds
    condition: and(succeeded('DeployStaging'), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: Prod
        environment: 'Production'
        steps:
          # Compile-time condition: include security scan step only in prod
          - ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/main') }}:
            - task: SonarQubeAnalyze@5

          - task: AzureWebApp@1
            # Step-level condition: skip if already deployed
            condition: and(succeeded(), ne(variables['SKIP_DEPLOY'], 'true'))

  - stage: SecurityScan
    jobs:
      - job: ScanDependencies
        # Only run on PRs targeting main
        condition: eq(variables['System.PullRequest.TargetBranch'], 'refs/heads/main')
        steps:
          - script: ./run-dependency-scan.sh
```

---

### Q34. How do runtime parameters work in Azure Pipelines YAML?

**Answer:** Runtime parameters (declared with `parameters:` at the top of a pipeline file) allow users to provide input values when manually queuing a pipeline run. Unlike variables, parameters support typed validation (string, boolean, number, object, stepList, jobList), enumerated allowed values, and are evaluated at compile time. They appear as UI controls in the Azure DevOps "Run pipeline" dialog. Parameters are referenced with `${{ parameters.paramName }}` syntax and can be passed through to templates.

❌ **Violates:**
```yaml
# Using unvalidated variable for environment selection — no type safety
variables:
  targetEnv: 'prod'   # anyone can pass any string, no validation
steps:
  - script: ./deploy.sh $(targetEnv)
  # Could accidentally deploy to wrong environment with a typo
```

✅ **Satisfies:**
```yaml
# Runtime parameters with typed validation
parameters:
  - name: environment
    displayName: 'Target Environment'
    type: string
    default: 'dev'
    values:             # dropdown in Run Pipeline UI
      - dev
      - staging
      - prod

  - name: runSmokeTests
    displayName: 'Run Smoke Tests?'
    type: boolean
    default: true

  - name: appVersion
    displayName: 'Version to Deploy (leave empty for latest)'
    type: string
    default: ''

trigger: none   # manual trigger only when using parameters

stages:
  - stage: Deploy_${{ parameters.environment }}
    displayName: 'Deploy to ${{ parameters.environment }}'
    jobs:
      - deployment: Deploy
        environment: ${{ parameters.environment }}
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    appName: 'myapp-${{ parameters.environment }}'

                - ${{ if eq(parameters.runSmokeTests, true) }}:
                  - script: ./smoke-tests.sh ${{ parameters.environment }}
```

---

### Q35. What are the three variable syntaxes in Azure Pipelines and when is each valid?

**Answer:** Azure Pipelines has three variable syntaxes serving different evaluation phases. `$(var)` is macro syntax — replaced by the agent at runtime just before each step executes; works everywhere in steps but cannot be used in conditions or template expressions. `${{ variables.var }}` is template expression syntax — evaluated at compile time when the pipeline YAML is processed; works in template parameters, conditionals, and anywhere before the job runs, but cannot reference runtime-set values. `$[variables.var]` is runtime expression syntax — evaluated by the agent at runtime; works in condition expressions and job-level fields like `dependsOn`.

❌ **Violates:**
```yaml
# Using macro syntax in condition — evaluated before runtime, always empty
stages:
  - stage: Prod
    condition: eq('$(Build.SourceBranch)', 'refs/heads/main')
    # $(Build.SourceBranch) in conditions is WRONG — use $[variables['Build.SourceBranch']]
```

✅ **Satisfies:**
```yaml
variables:
  myVar: 'hello'
  buildConfig: 'Release'

stages:
  - stage: Example
    # Runtime expression in condition — correct
    condition: eq($[variables['Build.SourceBranch']], 'refs/heads/main')
    jobs:
      - job: Demo
        steps:
          # Macro syntax — works in script arguments (evaluated by agent before step)
          - script: echo "Branch is $(Build.SourceBranch)"
          - script: dotnet build --configuration $(buildConfig)

          # Template expression — compile-time decision (evaluated when YAML is loaded)
          - ${{ if eq(variables.buildConfig, 'Release') }}:
            - script: echo "Release build — running additional checks"

          # Setting output variable (runtime)
          - bash: |
              echo "##vso[task.setvariable variable=myOutput;isOutput=true]computed_value"
            name: computeStep

          # Reading output variable with runtime expression
          - bash: echo "Output was $[dependencies.Demo.outputs['computeStep.myOutput']]"
            condition: ne($[dependencies.Demo.outputs['computeStep.myOutput']], '')
```

---

### Q36. How do you use script tasks to set output variables and pass values between steps?

**Answer:** Output variables allow a step to compute a value and make it available to subsequent steps, jobs, or stages. In Bash/PowerShell, output variables are set using the logging command `##vso[task.setvariable variable=name;isOutput=true]value`. The `isOutput=true` flag makes the variable accessible outside the current step. Within the same job, subsequent steps reference it as `$(stepName.varName)`. Across jobs, use `$[dependencies.jobName.outputs['stepName.varName']]`. Across stages, use `$[stageDependencies.stageName.jobName.outputs['stepName.varName']]`.

❌ **Violates:**
```yaml
# Trying to pass values via files across jobs — file doesn't exist on new agent
jobs:
  - job: Compute
    steps:
      - script: echo "1.2.3" > version.txt
      # Cannot read this file in a different job on a different agent

  - job: Deploy
    dependsOn: Compute
    steps:
      - script: cat version.txt  # file doesn't exist on new agent
```

✅ **Satisfies:**
```yaml
jobs:
  - job: Compute
    steps:
      - bash: |
          VERSION=$(cat version.txt)
          echo "##vso[task.setvariable variable=AppVersion;isOutput=true]$VERSION"
        name: setVersionStep
        displayName: 'Read and set version'

      - powershell: |
          Write-Host "##vso[task.setvariable variable=IsRelease;isOutput=true]true"
        name: checkRelease

  - job: Deploy
    dependsOn: Compute
    variables:
      # Map output variable from previous job
      APP_VERSION: $[dependencies.Compute.outputs['setVersionStep.AppVersion']]
      IS_RELEASE: $[dependencies.Compute.outputs['checkRelease.IsRelease']]
    steps:
      - script: |
          echo "Deploying version $(APP_VERSION)"
          echo "Is release: $(IS_RELEASE)"
```

---

### Q37. How do pipeline resources work — repositories, pipeline triggers, and container resources?

**Answer:** Resources declare external dependencies for a pipeline: `repositories` enables checking out code from multiple repos in a single pipeline (multi-repo builds), `pipelines` enables triggering this pipeline when another completes and consuming its artifacts, and `containers` enables running steps inside Docker images (useful for consistent toolchain environments). Container jobs ensure all steps run in a specified Docker image, eliminating "works on my machine" toolchain issues. Pipeline resources also enable cross-pipeline artifact consumption with `download:` steps.

❌ **Violates:**
```yaml
# Manually installing tools in every pipeline run — slow and inconsistent
steps:
  - script: |
      sudo apt-get install -y nodejs npm
      npm install -g @angular/cli@17
      # 3-5 minutes of tool installation per run, version may drift
```

✅ **Satisfies:**
```yaml
resources:
  # Multi-repo: checkout shared infrastructure scripts
  repositories:
    - repository: shared-scripts
      type: git
      name: MyOrg/DevOps-Scripts
      ref: refs/heads/main

  # Pipeline resource: trigger when CI pipeline completes
  pipelines:
    - pipeline: MyApp-CI
      source: 'MyApp-CI-Pipeline'
      trigger:
        branches: [main]

  # Container resources: pre-built images with tools installed
  containers:
    - container: dotnet8
      image: mcr.microsoft.com/dotnet/sdk:8.0
    - container: node18
      image: node:18-alpine

jobs:
  - job: BuildDotNet
    container: dotnet8     # all steps run inside this container
    steps:
      - checkout: self
      - checkout: shared-scripts    # checkout second repo
        path: scripts
      - script: dotnet build        # runs in dotnet/sdk:8.0

  - job: BuildAngular
    container: node18      # node 18 container — no manual install
    steps:
      - script: npm ci
      - script: npm run build

  # Consume artifact from pipeline resource
  - job: Deploy
    steps:
      - download: MyApp-CI          # download artifact from CI pipeline resource
        artifact: webapp
```

---

### Q38. How do you use strategy matrix for testing across multiple .NET versions and operating systems?

**Answer:** A matrix strategy creates multiple instances of a job with different variable combinations, running them in parallel. Each matrix entry defines key-value pairs that become variables within that job instance. `maxParallel` limits how many matrix jobs run simultaneously (important for parallel job quotas). Matrix is ideal for library projects that must support multiple target frameworks, or applications that must work cross-platform. Combining 2 OS × 3 .NET versions creates 6 parallel jobs from a single job definition.

❌ **Violates:**
```yaml
# Manually duplicating test jobs for each framework — 6 copies to maintain
jobs:
  - job: TestNet6_Ubuntu
    steps:
      - script: dotnet test --framework net6.0
  - job: TestNet7_Ubuntu
    steps:
      - script: dotnet test --framework net7.0
  - job: TestNet8_Ubuntu
    steps:
      - script: dotnet test --framework net8.0
  # Adding Windows doubles to 6 copies — all must be maintained separately
```

✅ **Satisfies:**
```yaml
jobs:
  - job: CrossPlatformTest
    strategy:
      matrix:
        Net6_Ubuntu:
          vmImage: 'ubuntu-latest'
          dotnetVersion: '6.x'
          framework: 'net6.0'
        Net6_Windows:
          vmImage: 'windows-latest'
          dotnetVersion: '6.x'
          framework: 'net6.0'
        Net7_Ubuntu:
          vmImage: 'ubuntu-latest'
          dotnetVersion: '7.x'
          framework: 'net7.0'
        Net7_Windows:
          vmImage: 'windows-latest'
          dotnetVersion: '7.x'
          framework: 'net7.0'
        Net8_Ubuntu:
          vmImage: 'ubuntu-latest'
          dotnetVersion: '8.x'
          framework: 'net8.0'
        Net8_Windows:
          vmImage: 'windows-latest'
          dotnetVersion: '8.x'
          framework: 'net8.0'
      maxParallel: 6

    pool:
      vmImage: $(vmImage)

    steps:
      - task: UseDotNet@2
        inputs:
          version: $(dotnetVersion)

      - task: DotNetCoreCLI@2
        displayName: 'Test on $(framework)'
        inputs:
          command: test
          arguments: '--framework $(framework) --logger trx'
          publishTestResults: true
```

---

### Q39. What are extends templates and how do they enforce security compliance in pipelines?

**Answer:** The `extends:` keyword forces a pipeline to inherit from an organization-mandated template, enabling security teams to inject required steps (SAST scans, compliance checks, approved registries) that individual teams cannot bypass. Unlike regular template includes, `extends` makes the template the root of the pipeline — the consuming pipeline can only provide parameters declared by the template. This is used with "protected" template files that require specific Azure DevOps permissions to modify, ensuring all pipelines in the org run mandatory security scans.

❌ **Violates:**
```yaml
# Pipeline with no extends — team can skip required security scans
trigger: [main]
steps:
  - task: DotNetCoreCLI@2
    inputs: { command: build }
  # No mandatory SAST scan, no approved registry check
  # Security team has no way to enforce compliance across all pipelines
```

✅ **Satisfies:**
```yaml
# templates/secure-pipeline.yml (in a protected repository, restricted permissions)
parameters:
  - name: buildSteps
    type: stepList
    default: []
  - name: deployEnvironment
    type: string
    default: 'dev'
    values: [dev, staging, prod]

stages:
  - stage: MandatorySecurityChecks
    jobs:
      - job: SecurityScan
        steps:
          - task: CredScan@3           # required: credential scanning
          - task: SonarQubePrepare@5   # required: SAST

  - stage: Build
    dependsOn: MandatorySecurityChecks
    jobs:
      - job: UserBuild
        steps:
          - ${{ each step in parameters.buildSteps }}:
            - ${{ step }}              # user-provided steps inserted here

  - stage: PostBuildCompliance
    jobs:
      - job: ComplianceCheck
        steps:
          - task: ComponentGovernanceComponentDetection@0  # required: license scan
```

```yaml
# azure-pipelines.yml (team pipeline — must use extends, cannot bypass)
extends:
  template: templates/secure-pipeline.yml@compliance-templates
  parameters:
    deployEnvironment: 'staging'
    buildSteps:
      - task: DotNetCoreCLI@2
        inputs: { command: build }
      - task: DotNetCoreCLI@2
        inputs: { command: test }
```

---

### Q40. How do workspace and checkout settings affect pipeline performance and behavior?

**Answer:** The `checkout:` step controls how source code is fetched. `checkout: none` skips code checkout entirely (useful in deployment jobs that only need artifacts), `fetchDepth: 1` performs a shallow clone (faster for large repos), and `clean: true` removes uncommitted changes from a previous run on the same self-hosted agent. The `workspace:` setting controls what gets cleaned between runs on self-hosted agents. For CI jobs, `fetchDepth: 1` is typically sufficient; for GitVersion or git log operations, a deeper or full fetch is needed.

❌ **Violates:**
```yaml
# Checking out full history in every job including deployment jobs
jobs:
  - deployment: DeployToProd
    steps:
      - checkout: self   # fetches entire repo history — unnecessary for deploy job
      # Deploy job only needs the artifact, not source code
```

✅ **Satisfies:**
```yaml
jobs:
  - job: Build
    steps:
      - checkout: self
        fetchDepth: 1        # shallow clone — sufficient for build
        clean: false

  - job: Version
    steps:
      - checkout: self
        fetchDepth: 0        # full history required for GitVersion

  - deployment: DeployProd
    environment: 'Production'
    strategy:
      runOnce:
        deploy:
          steps:
            - checkout: none   # no source needed, only artifact
            - task: DownloadPipelineArtifact@2
              inputs: { artifactName: 'webapp' }
            - task: AzureWebApp@1

  - job: CleanBuild
    workspace:
      clean: all    # clean outputs + sources on self-hosted agent
    steps:
      - checkout: self
        fetchDepth: 1
```

> 📚 Reference: [Azure Pipelines YAML Templates](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/templates)
> 📚 Medium: [Mastering Azure Pipelines YAML — Templates, Conditions, and Matrix Builds](https://medium.com/mastering-azure-pipelines-yaml)

---

## Section 5 — Artifacts & Package Management

### Q41. What are Azure Artifacts feeds and how do upstream sources work?

**Answer:** Azure Artifacts feeds are package repositories that host NuGet, npm, Maven, Python (PyPI), and Universal packages privately within your organization. Upstream sources allow a feed to proxy requests to public registries (nuget.org, npmjs.com) so developers can restore all packages — private and public — through a single authenticated feed endpoint. If a package is not in the private feed, the upstream source fetches it, caches a copy, and returns it. This protects against supply chain attacks by letting you block direct access to public registries and control which packages are available.

❌ **Violates:**
```xml
<!-- nuget.config pointing directly to nuget.org — bypasses private feed, 
     no supply chain control, credentials not centrally managed -->
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
```

✅ **Satisfies:**
```xml
<!-- nuget.config — all packages through Azure Artifacts feed with upstream -->
<configuration>
  <packageSources>
    <clear />
    <!-- Single source: private feed with nuget.org upstream configured -->
    <add key="AzureArtifacts"
         value="https://pkgs.dev.azure.com/MyOrg/MyProject/_packaging/MyFeed/nuget/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <AzureArtifacts>
      <!-- In CI: $(System.AccessToken) auto-populated -->
      <add key="Username" value="azure-pipelines" />
      <add key="ClearTextPassword" value="$(System.AccessToken)" />
    </AzureArtifacts>
  </packageSourceCredentials>
</configuration>
```

---

### Q42. How do you publish a NuGet package to Azure Artifacts from a CI pipeline?

**Answer:** Publishing NuGet packages involves three steps: `dotnet pack` to create the .nupkg file with the correct version, `dotnet nuget push` (or `NuGetCommand@2` task) to authenticate and push to the feed, and enforcing SemVer versioning using GitVersion or explicit version properties. The service principal running the pipeline needs Contributor role on the feed. Pre-release packages use version suffixes like `-alpha.1`, `-beta.2`, `-preview.1`.

❌ **Violates:**
```yaml
# No version specified — defaults to 1.0.0 every time, overwrites previous
steps:
  - script: dotnet pack
  - script: dotnet nuget push *.nupkg
  # Every build overwrites version 1.0.0, no version history
```

✅ **Satisfies:**
```yaml
steps:
  - task: gitversion/setup@0
    inputs: { versionSpec: '5.x' }

  - task: gitversion/execute@0
    name: gitVersion

  - task: DotNetCoreCLI@2
    displayName: 'Pack NuGet package'
    inputs:
      command: pack
      packagesToPack: 'src/MyLibrary/MyLibrary.csproj'
      nobuild: true
      versioningScheme: byEnvVar
      versionEnvVar: 'GitVersion.NuGetVersion'
      # Results in: MyLibrary.2.3.1.nupkg (release) or MyLibrary.2.3.1-alpha.3.nupkg (feature)

  - task: NuGetCommand@2
    displayName: 'Push to Azure Artifacts'
    inputs:
      command: push
      packagesToPush: '$(Build.ArtifactStagingDirectory)/**/*.nupkg;!**/*.symbols.nupkg'
      nuGetFeedType: internal
      publishVstsFeed: 'MyProject/MyFeed'
      allowPackageConflicts: false  # fail if version already exists (prevents overwrites)
```

---

### Q43. How do you consume private NuGet packages from Azure Artifacts in a CI pipeline?

**Answer:** Consuming Azure Artifacts NuGet packages in CI requires authenticating the `dotnet restore` command using the pipeline's built-in `$(System.AccessToken)`. The `nuget.config` in the repository points to the Azure Artifacts feed URL. The `NuGetAuthenticate@1` task injects credentials automatically without exposing the token in the config file. This works for both Microsoft-hosted and self-hosted agents without manual credential management.

❌ **Violates:**
```yaml
# Hardcoded PAT in nuget.config checked into source control
# nuget.config: <add key="ClearTextPassword" value="pat123abc456" />
# PAT visible to all repo contributors, rotates manually
steps:
  - task: DotNetCoreCLI@2
    inputs: { command: restore }
  # Fails when PAT expires; secret in Git history
```

✅ **Satisfies:**
```yaml
steps:
  # Inject credentials automatically using pipeline token
  - task: NuGetAuthenticate@1
    displayName: 'Authenticate to Azure Artifacts'
    inputs:
      nuGetServiceConnections: ''   # leave empty for org feeds; specify for cross-org

  - task: DotNetCoreCLI@2
    displayName: 'Restore packages'
    inputs:
      command: restore
      projects: '**/*.csproj'
      feedsToUse: config
      nugetConfigPath: nuget.config   # points to Azure Artifacts feed URL
      # $(System.AccessToken) injected automatically by NuGetAuthenticate task

  - task: DotNetCoreCLI@2
    displayName: 'Build'
    inputs:
      command: build
      arguments: '--no-restore'
```

---

### Q44. How do you publish and consume npm packages from a private Azure Artifacts feed?

**Answer:** Private npm packages for internal libraries (e.g., a shared Angular component library) are published to Azure Artifacts npm feeds. The `.npmrc` file scopes package names (e.g., `@myorg/`) to the private feed registry URL. Authentication in CI uses `$(System.AccessToken)` via the `npmAuthenticate@0` task, which populates credentials for the scoped registry. Publishing uses `npm publish` from the package directory after building.

❌ **Violates:**
```bash
# Publishing to public npmjs.com accidentally
npm publish
# Internal library becomes publicly downloadable
# No access control, exposes proprietary code
```

✅ **Satisfies:**
```yaml
# .npmrc in package root (committed to repo):
# @myorg:registry=https://pkgs.dev.azure.com/MyOrg/MyProject/_packaging/MyFeed/npm/registry/
# always-auth=true
# (credentials NOT in this file — injected by CI task)

steps:
  - task: npmAuthenticate@0
    displayName: 'Authenticate npm to Azure Artifacts'
    inputs:
      workingFile: 'ClientApp/.npmrc'   # path to .npmrc file

  - script: npm ci
    displayName: 'Install dependencies'
    workingDirectory: ClientApp

  - script: npm run build -- --configuration production
    displayName: 'Build Angular library'
    workingDirectory: ClientApp

  - script: npm run build-lib   # builds the shared library
    workingDirectory: ClientApp

  - task: Npm@1
    displayName: 'Publish to Azure Artifacts'
    inputs:
      command: publish
      workingDir: 'ClientApp/dist/my-shared-lib'
      publishRegistry: useFeed
      publishFeed: 'MyProject/MyNpmFeed'
      publishPackageMetadata: true
```

---

### Q45. What are Universal Packages in Azure Artifacts and when should you use them?

**Answer:** Universal Packages store arbitrary files and directories (binaries, zip archives, scripts, Terraform modules, test fixtures) that don't fit NuGet/npm/Maven formats. They have versioned uploads and downloads via the `UniversalPackages@0` task. Use Universal Packages when you need to share build outputs (compiled binaries), large test data sets, or infrastructure modules across pipelines without using the pipeline artifact store. They support semantic versioning and retention policies like other feed packages.

❌ **Violates:**
```yaml
# Storing non-package artifacts in Git LFS — slow, expensive, pollutes repo
git lfs track "*.exe"
git add deployment-tools/myapp-installer-2.3.1.exe
git commit -m "add installer binary"
# Binary files in Git increase clone time, storage costs, and version management pain
```

✅ **Satisfies:**
```yaml
# Publish universal package (build output)
- task: UniversalPackages@0
  displayName: 'Publish Universal Package'
  inputs:
    command: publish
    publishDirectory: '$(Build.ArtifactStagingDirectory)/tools'
    feedsToUsePublish: internal
    vstsFeedPublish: 'MyProject/ToolsFeed'
    vstsFeedPackagePublish: 'deployment-tools'
    versionOption: patch     # auto-increment patch version
    packagePublishDescription: 'Deployment tools bundle'

# Download universal package in another pipeline
- task: UniversalPackages@0
  displayName: 'Download Deployment Tools'
  inputs:
    command: download
    downloadDirectory: '$(Pipeline.Workspace)/tools'
    feedsToUse: internal
    vstsFeed: 'MyProject/ToolsFeed'
    vstsFeedPackage: 'deployment-tools'
    vstsPackageVersion: '1.2.*'    # latest patch of 1.2.x
```

---

### Q46. How do feed permissions work in Azure Artifacts?

**Answer:** Azure Artifacts feeds have four roles: Owner (manage feed settings and delete), Contributor (publish packages), Reader (download packages), and Collaborator (can use upstream sources). In CI/CD, the build service account (Project Collection Build Service or Project Build Service) needs Contributor role to publish and Reader role to consume. Org-scoped feeds expose packages to all projects; project-scoped feeds restrict to the project. Blocking external upstream sources prevents developers from accidentally introducing unlicensed or vulnerable packages.

❌ **Violates:**
```yaml
# Granting everyone Owner role on the feed
# Any developer can delete published packages
# No separation between publish (CI) and consume (developers) roles
```

✅ **Satisfies:**
```yaml
# Feed permission configuration (set via Azure DevOps UI or REST API):
# Feed: MyProject/MyFeed
#
# Roles:
# - [Project] Build Service (MyProject): Contributor  ← CI pipeline publishes
# - Developers group: Reader                           ← developers consume
# - Release Engineers group: Owner                    ← manage feed
# - External developers: no access (feed is project-scoped)
#
# Upstream sources:
# - nuget.org: enabled but restricted to allowed list
# - npmjs.com: enabled
# - Internal feeds: enabled

# In pipeline: uses $(System.AccessToken) — automatically has Build Service permissions
- task: NuGetAuthenticate@1
- task: DotNetCoreCLI@2
  inputs:
    command: restore   # Build Service Reader role allows this
- task: NuGetCommand@2
  inputs:
    command: push      # Build Service Contributor role allows this
```

---

### Q47. How do package retention policies work in Azure Artifacts?

**Answer:** Azure Artifacts charges based on storage used beyond the 2 GB free tier. Retention policies automatically delete old package versions to control costs. Policies can keep the latest N versions per package, delete versions older than X days, or protect specific versions from deletion (e.g., release versions tagged as "release"). Deleting a package version is permanent and can break pipelines that reference that exact version — always test that pipelines use version ranges (`1.2.*`) or latest rather than pinned patch versions before deleting.

❌ **Violates:**
```yaml
# No retention policy — feed grows indefinitely
# After 6 months: 500 package versions, 50 GB storage, $20/month overage
# Manually deleting is error-prone and time-consuming
```

✅ **Satisfies:**
```yaml
# Retention policy (configured in Azure DevOps > Artifacts > Feed Settings > Retention):
# - Keep latest 10 versions of each package
# - Delete versions older than 90 days
# - Exception: packages tagged with 'release' are never auto-deleted
#
# Also: use pipeline artifact retention separate from feed retention
# Pipeline artifacts (PublishPipelineArtifact) have their own retention:
# - PR builds: 10 days
# - Branch builds: 30 days
# - Release pipeline artifacts: 365 days

# In project settings > Settings > Retention:
# Maximum retention policy: 365 days
# Default retention for runs: 30 days

# Best practice: pin to minor version in consuming projects
# <PackageReference Include="MyLibrary" Version="1.2.*" />
# This survives patch version cleanup while still being deterministic
```

---

### Q48. How do symbol packages and source indexing work in Azure Artifacts?

**Answer:** Symbol packages (`.snupkg`) contain `.pdb` debug symbol files that map compiled IL code back to source lines, enabling step-through debugging of NuGet packages in Visual Studio without having the source code. Azure Artifacts hosts a symbol server endpoint. Developers configure Visual Studio to use the Azure Artifacts symbol server, and when debugging they can step into the library's source code. Source link embeds source retrieval URLs in PDB files so the debugger automatically fetches the correct source version from Azure Repos.

❌ **Violates:**
```yaml
# Publishing packages without symbols — consumers cannot debug into the library
dotnet pack --configuration Release
dotnet nuget push *.nupkg
# When debugging MyLibrary.dll, Visual Studio shows decompiled code without variable names
# Support requests increase: "I can't step through your library to debug my issue"
```

✅ **Satisfies:**
```yaml
steps:
  - task: DotNetCoreCLI@2
    displayName: 'Pack with symbols'
    inputs:
      command: pack
      packagesToPack: 'src/MyLibrary/MyLibrary.csproj'
      includesymbols: true       # generates .snupkg alongside .nupkg
      arguments: >
        /p:SymbolPackageFormat=snupkg
        /p:EmbedAllSources=true  # embeds source files in PDB (alternative to source link)
        /p:ContinuousIntegrationBuild=true

  - task: NuGetCommand@2
    displayName: 'Push package + symbols'
    inputs:
      command: push
      packagesToPush: '$(Build.ArtifactStagingDirectory)/**/*.nupkg'
      nuGetFeedType: internal
      publishVstsFeed: 'MyProject/MyFeed'
      publishSymbols: true   # publishes .snupkg to symbol server

# In MyLibrary.csproj for source link support:
# <PackageReference Include="Microsoft.SourceLink.AzureRepos.Git" Version="8.*" PrivateAssets="All" />
# <PublishRepositoryUrl>true</PublishRepositoryUrl>
# <DebugType>embedded</DebugType>
```

---

### Q49. How do you integrate dependency vulnerability scanning into Azure Pipelines?

**Answer:** Dependency scanning checks packages used by the project for known CVEs (Common Vulnerabilities and Exposures). OWASP Dependency-Check and Snyk are popular tools. In Azure Pipelines, Snyk integrates via the Snyk Security Scan task or CLI; OWASP Dependency-Check runs as a script task. The scan should fail the pipeline when high or critical severity vulnerabilities are found (`--severity-threshold=high`), preventing vulnerable dependencies from reaching production. Results publish as build artifacts for audit trails.

❌ **Violates:**
```yaml
# No dependency scanning — vulnerable packages ship to production undetected
# Log4Shell, CVE-2021-44228 would have been caught by Snyk/OWASP scan
steps:
  - task: DotNetCoreCLI@2
    inputs: { command: restore }
  - task: DotNetCoreCLI@2
    inputs: { command: build }
  # Deploys to prod without checking for known CVEs
```

✅ **Satisfies:**
```yaml
steps:
  - task: DotNetCoreCLI@2
    inputs: { command: restore }

  # Option 1: Snyk
  - task: SnykSecurityScan@1
    displayName: 'Snyk: Dependency Vulnerability Scan'
    inputs:
      serviceConnectionEndpoint: 'Snyk-Connection'
      testType: 'app'
      severityThreshold: 'high'    # fail on HIGH or CRITICAL CVEs
      failOnIssues: true
      monitorWhen: 'always'        # report to Snyk dashboard
      additionalArguments: '--all-projects'

  # Option 2: OWASP Dependency-Check
  - task: dependency-check-build-task@6
    displayName: 'OWASP Dependency Check'
    inputs:
      projectName: '$(Build.Repository.Name)'
      scanPath: '$(Build.SourcesDirectory)'
      format: 'HTML,JUNIT'
      failOnCVSS: '7'              # fail on CVSS score >= 7 (HIGH)
      additionalArguments: '--enableRetired'

  - task: PublishTestResults@2
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '**/dependency-check-junit.xml'
      failTaskOnFailedTests: true
```

---

### Q50. What versioning strategies are available for NuGet packages and how does GitVersion work?

**Answer:** Three main versioning strategies: **GitVersion** (SemVer computed from Git history, branch names, and tags — fully automatic), **CalVer** (Calendar Versioning like 2024.12.15.1 — date-based, easy to trace), and **manual** (explicitly set in .csproj `<Version>` property, requires developer discipline). GitVersion reads your repository's commit history and branch name to determine version: feature branches get pre-release suffixes, `main` increments based on commit messages (`+semver: major/minor`), and tags mark releases. A `GitVersion.yml` configuration file controls the rules.

❌ **Violates:**
```xml
<!-- Manual version in .csproj that developers forget to update -->
<PropertyGroup>
  <Version>1.0.0</Version>
  <!-- Every package published as 1.0.0, overwrites previous, no history -->
</PropertyGroup>
```

✅ **Satisfies:**
```yaml
# GitVersion.yml in repo root
mode: Mainline
assembly-versioning-scheme: MajorMinorPatch
assembly-file-versioning-scheme: MajorMinorPatchTag
tag-prefix: '[vV]'
major-version-bump-message: '\+semver:\s?(breaking|major)'
minor-version-bump-message: '\+semver:\s?(feature|minor)'
patch-version-bump-message: '\+semver:\s?(fix|patch)'
no-bump-message: '\+semver:\s?none'

branches:
  main:
    regex: ^master$|^main$
    tag: ''
    increment: Patch
  feature:
    regex: ^feature[/-]
    tag: alpha
    increment: Minor
  release:
    regex: ^release[/-]
    tag: beta
    increment: None
```

```yaml
# Pipeline using GitVersion
steps:
  - task: gitversion/setup@0
    inputs: { versionSpec: '5.x' }

  - task: gitversion/execute@0
    # Exposes: $(GitVersion.Major), $(GitVersion.Minor), $(GitVersion.Patch)
    # $(GitVersion.SemVer) = "2.3.1" (release) or "2.3.1-alpha.5" (feature branch)
    # $(GitVersion.NuGetVersion) = "2.3.1" or "2.3.1-alpha0005"

  - task: DotNetCoreCLI@2
    inputs:
      command: pack
      versioningScheme: byEnvVar
      versionEnvVar: GitVersion.NuGetVersion
```

> 📚 Reference: [Azure Artifacts Documentation](https://docs.microsoft.com/en-us/azure/devops/artifacts/)
> 📚 Medium: [Private NuGet Feeds with Azure Artifacts and GitVersion](https://medium.com/private-nuget-feeds-azure-artifacts)

---

## Section 6 — Pipeline Security & Secrets

### Q51. How do you link variable groups to Azure Key Vault in Azure Pipelines?

**Answer:** Linking a variable group to Azure Key Vault allows pipelines to consume secrets stored in Key Vault without ever having those values appear in YAML or the Azure DevOps variable store. The link is configured in Azure DevOps > Pipelines > Library > Variable Groups — specify the Azure subscription service connection and the Key Vault name, then select which secrets to expose. The pipeline service principal must have Key Vault Secrets User role. Secrets are refreshed at each pipeline run. In YAML, the variable group is referenced under `variables:` and secrets are consumed like any variable with `$(SecretName)`.

❌ **Violates:**
```yaml
# Secrets stored as plain-text pipeline variables — visible in UI, logged
variables:
  DB_PASSWORD: 'SuperSecret123!'
  API_KEY: 'sk-prod-abc123xyz'
  # Anyone with Contributor access can read these in the pipeline UI
  # Secrets appear in "Edit variable" fields unmasked
```

✅ **Satisfies:**
```yaml
# Variable group 'Prod-KeyVault-Secrets' is linked to Azure Key Vault
# Key Vault secrets: DB-Password, Api-Key, ServiceBus-ConnectionString
# Service principal has 'Key Vault Secrets User' role

variables:
  - group: 'Prod-KeyVault-Secrets'   # secrets fetched from Key Vault at run time
  - name: appName
    value: 'myapp-prod'

steps:
  - task: AzureWebApp@1
    inputs:
      appName: $(appName)
      appSettings: |
        -ConnectionStrings__Default "$(DB-Password)"
        -ExternalApi__Key "$(Api-Key)"
      # $(DB-Password) resolved from Key Vault, masked in logs as ***
```

---

### Q52. What is the difference between a service principal and managed identity for Azure authentication in pipelines?

**Answer:** A service principal is an application identity with a client ID and secret/certificate that must be rotated periodically — if the secret leaks, attackers can authenticate as the principal. A managed identity is an Azure-managed identity with no credentials — Azure handles key rotation automatically, and the identity is bound to the Azure resource (VM, App Service). For Azure-hosted self-hosted agents running as Azure VMs, managed identity is strongly preferred: no credentials in YAML, no rotation, no leakage risk. OIDC (Workload Identity Federation) extends this zero-credential model to Microsoft-hosted agents.

❌ **Violates:**
```yaml
# Service principal with client secret in pipeline variable
variables:
  CLIENT_ID: '00000000-0000-0000-0000-000000000000'
  CLIENT_SECRET: 'abc~secretvalue~xyz'   # must rotate, leaks if logged

steps:
  - script: |
      az login --service-principal -u $(CLIENT_ID) -p $(CLIENT_SECRET) --tenant $(TENANT_ID)
      # If CLIENT_SECRET leaks: full access to Azure subscription
```

✅ **Satisfies:**
```yaml
# Option 1: Managed Identity on self-hosted agent VM
# VM has system-assigned managed identity with required Azure RBAC roles
# No credentials anywhere — Azure handles auth automatically
steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'ManagedIdentity-ServiceConnection'   # uses managed identity
      scriptType: bash
      inlineScript: |
        az webapp deploy --name myapp --resource-group myRG

# Option 2: Service principal with certificate (not secret) — more secure
# - Certificate in Key Vault, no string secret to leak
# - Service connection uses certificate thumbprint

# Option 3: OIDC/Workload Identity Federation (no credentials at all)
# - Service connection configured with federation
# - Pipeline exchanges short-lived OIDC token for Azure access token
# - See Q53 for full OIDC setup
```

---

### Q53. How does secret masking work in Azure Pipelines and how do you prevent accidental leaks?

**Answer:** When a variable is marked as secret (`isSecret: true`) or comes from a Key Vault-linked variable group, Azure Pipelines automatically masks its value in all log output, replacing it with `***`. However, masking only works for exact string matches — if a secret is base64-encoded or split across multiple log lines, it may not be masked. Best practices: never echo secrets, never pass them as command-line arguments (visible in process listings), use environment variables for secret injection, and avoid writing secrets to files that are later published as artifacts.

❌ **Violates:**
```yaml
# Echoing secrets in scripts — logs show the value before masking kicks in
steps:
  - script: |
      echo "Connection string: $(DB_ConnectionString)"   # masking too late
      dotnet run --connection "$(DB_ConnectionString)"   # visible in process list
      cat appsettings.json  # if secret was written to file and file is printed
```

✅ **Satisfies:**
```yaml
variables:
  - group: 'Prod-KeyVault-Secrets'

steps:
  # Inject secret as environment variable — not in command-line arguments
  - task: DotNetCoreCLI@2
    displayName: 'Run with secret via env var'
    inputs:
      command: custom
      custom: run
    env:
      ConnectionStrings__Default: $(DB-ConnectionString)   # injected as env var
      # Not logged, not in process args, Azure automatically masks $(DB-ConnectionString)

  # Setting a variable as secret dynamically
  - bash: |
      TOKEN=$(curl -s https://auth.service/token | jq -r '.access_token')
      echo "##vso[task.setvariable variable=DynamicToken;isSecret=true]$TOKEN"
    name: fetchToken

  # Never do this:
  # - script: echo $(DB-ConnectionString)     <- leaks in logs
  # - script: ./app --key=$(API_KEY)          <- visible in process list
  # - script: printenv                        <- dumps all env vars including secrets
```

---

### Q54. What is OIDC/Workload Identity Federation for passwordless Azure authentication in pipelines?

**Answer:** Workload Identity Federation allows Azure Pipelines to authenticate to Azure without any stored credentials using OIDC (OpenID Connect). Azure DevOps acts as an OIDC identity provider and issues short-lived tokens for each pipeline run. Azure AD trusts these tokens via a federated credential configured on the service principal. The pipeline's service connection uses `workloadIdentityFederation` instead of a client secret. The token is valid for the pipeline run only and automatically expires — eliminating credential rotation, secret storage, and leak risks entirely.

❌ **Violates:**
```yaml
# Classic service connection with client secret
# azure-pipelines.yml references service connection with stored secret
steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'MyApp-Azure-SC'  # backed by client secret expiring in 1 year
      # Secret must be rotated annually, stored in Azure DevOps, visible to Owners
```

✅ **Satisfies:**
```yaml
# Service connection configured with Workload Identity Federation:
# Azure DevOps > Project Settings > Service Connections > New > Azure Resource Manager
# Authentication: Workload Identity Federation (automatic)
# Azure AD: federated credential created automatically
# No secret stored anywhere

steps:
  - task: AzureCLI@2
    displayName: 'Deploy (OIDC — no credentials)'
    inputs:
      azureSubscription: 'MyApp-OIDC-Connection'   # uses OIDC federation
      scriptType: bash
      inlineScript: |
        az webapp deploy \
          --name myapp-prod \
          --resource-group rg-prod \
          --src-path app.zip
    # Behind the scenes:
    # 1. Azure DevOps issues OIDC token for this run
    # 2. AzureCLI task exchanges it for short-lived Azure access token
    # 3. Access token used for az CLI commands
    # 4. Token expires when pipeline run ends
    # No stored credentials, no rotation needed
```

---

### Q55. What are Secure Files in Azure Pipelines and when should you use them?

**Answer:** Secure Files is a library in Azure DevOps for storing sensitive files that pipelines need during execution — code signing certificates (.pfx), SSH private keys, Apple provisioning profiles, or any secret file. Unlike variables, Secure Files store binary content. The `DownloadSecureFile@1` task downloads the file to a temporary directory that is automatically deleted after the job completes. Files can be locked to specific pipelines and require approval to use, preventing unauthorized access.

❌ **Violates:**
```bash
# Storing certificates in Git repository — terrible security practice
git add signing-cert.pfx
git commit -m "add code signing certificate"
# Certificate and private key visible to all repo contributors
# In Git history permanently even after deletion
```

✅ **Satisfies:**
```yaml
# Certificate uploaded to Azure DevOps > Pipelines > Library > Secure Files
# Permissions: restrict to 'MyApp-Release' pipeline only

steps:
  - task: DownloadSecureFile@1
    displayName: 'Download code signing certificate'
    name: signingCert           # task name to reference output variables
    inputs:
      secureFile: 'MyApp-CodeSigning.pfx'
      # $(signingCert.secureFilePath) = path to downloaded file

  - task: PowerShell@2
    displayName: 'Sign application'
    inputs:
      targetType: inline
      script: |
        $certPath = "$(signingCert.secureFilePath)"
        $certPassword = "$(CERT_PASSWORD)"  # from Key Vault variable group
        signtool.exe sign /f "$certPath" /p "$certPassword" /tr http://timestamp.digicert.com /td sha256 "$(Build.ArtifactStagingDirectory)/MyApp.exe"
    # Certificate file automatically deleted from agent after job completes
```

---

### Q56. What are Protected Resources in Azure Pipelines and how do they prevent unauthorized use?

**Answer:** Protected resources (environments, variable groups, service connections, agent pools, repositories, and Secure Files) can be locked to specific pipelines and require approval before a new pipeline can use them for the first time. When a new pipeline references a protected resource, the pipeline is paused and an administrator must approve it. Additionally, resource restrictions can limit which branches can trigger deployments (e.g., only `main` branch can deploy to `Production` environment), preventing feature branches from accessing production resources.

❌ **Violates:**
```yaml
# No resource protection — any pipeline created by any contributor
# can immediately use the Production service connection
steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'Production-SC'  # unprotected — any pipeline can use
      inlineScript: az resource delete --ids /subscriptions/.../resources/...
```

✅ **Satisfies:**
```yaml
# Protected resources configured in Azure DevOps UI:
#
# Environments > Production > Security:
# - Pipeline permissions: only 'MyApp-Release-Pipeline'
# - Branch control: only 'refs/heads/main' can deploy here
#
# Service Connections > Production-SC > Security:
# - Pipeline permissions: restricted to specific pipelines
# - User permissions: only Release-Managers group
#
# Variable Groups > Prod-Secrets > Pipeline permissions:
# - Restricted: must approve new pipeline requests

# When a new pipeline tries to use 'Production' environment,
# Azure DevOps sends approval request to environment admins.
# Until approved, pipeline is paused on first run.

stages:
  - stage: Prod
    condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
    jobs:
      - deployment: ProdDeploy
        environment: 'Production'    # protected environment
```

---

### Q57. How do pipeline permissions and security roles work in Azure DevOps?

**Answer:** Pipeline permissions operate at multiple levels: organization, project, and individual pipeline. At the project level, Contributors can create and edit pipelines; Readers can view results; Build Administrators can manage agent pools and settings. At the pipeline level, individual pipelines can have custom permissions overriding project defaults. Service connections, environments, and variable groups each have their own permission sets. The principle of least privilege: developers get Contributor access to edit code and queue builds, but only Release Engineers can approve production deployments.

❌ **Violates:**
```yaml
# All developers are Project Administrators — can approve their own PRs,
# modify branch policies, access all secrets, approve production deployments
# No separation of duties, single person can go from commit to production unreviewed
```

✅ **Satisfies:**
```yaml
# Recommended permission structure:
#
# Project level:
# - Developers group:
#   - Repos: Contribute, Create branches, Read
#   - Pipelines: Queue builds, View builds
#   - Boards: Edit work items
# - Senior Developers group:
#   - + Pipelines: Edit pipelines
#   - + Repos: Bypass branch policies (emergency only)
# - Release Engineers group:
#   - + Environments: Approve production deployments
#   - + Service Connections: Administer (create, edit)
# - DevOps Admins group:
#   - Project Administrators
#   - Agent Pool Administrators
#
# Individual pipeline permissions:
# - Production release pipeline: only Release Engineers can manually queue
# - Edit pipeline definition: only Senior Developers and DevOps Admins
#
# Branch policies (enforced by permissions):
# - main: require 2 reviewers, no self-approval, build validation required
```

---

### Q58. How do you restrict production deployments to only the main branch in YAML?

**Answer:** Branch-based deployment restrictions prevent feature branches, hotfix branches, or accidentally pushed branches from deploying to production. In YAML, use `condition:` on the production stage with `eq(variables['Build.SourceBranch'], 'refs/heads/main')`. Additionally, Azure DevOps Environments support Branch Control checks — a protected check that rejects deployment requests from any branch not matching the allowlist, providing a server-side enforcement that cannot be bypassed by editing the YAML.

❌ **Violates:**
```yaml
# No branch check — any branch can trigger production deployment
stages:
  - stage: Production
    dependsOn: Staging
    condition: succeeded('Staging')   # only checks staging passed, not branch
    jobs:
      - deployment: Prod
        environment: 'Production'
        # feature/experiment branch could accidentally deploy to prod
```

✅ **Satisfies:**
```yaml
stages:
  - stage: Production
    dependsOn: Staging
    # YAML-level condition: only main branch
    condition: >
      and(
        succeeded('Staging'),
        eq(variables['Build.SourceBranch'], 'refs/heads/main')
      )
    jobs:
      - deployment: Prod
        environment: 'Production'   # + server-side Branch Control check
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1

# Environment Branch Control check (configured in Azure DevOps UI):
# Production environment > Approvals and Checks > Branch Control
# Allowed branches: refs/heads/main
# Verify branch protection: checked
# This is SERVER-SIDE — cannot be bypassed by YAML edits
```

---

### Q59. What is Azure DevOps audit logging and how do you stream it to a SIEM?

**Answer:** Azure DevOps maintains an audit log of all significant actions: pipeline runs, permission changes, secret access, service connection modifications, user additions/removals, and policy changes. The audit log is accessible in Organization Settings > Audit. Streaming sends audit events in real-time to Azure Monitor (Log Analytics), Splunk, or other SIEM systems via configured audit streams. This enables security teams to alert on suspicious activity (e.g., someone disabling branch policies or accessing production service connections outside normal hours).

❌ **Violates:**
```yaml
# No audit streaming — security incidents discovered weeks later
# Attacker modifies branch policy, merges malicious code to main, disables CI
# No alert fired, incident not detected for weeks
# Forensic investigation impossible without audit log access
```

✅ **Satisfies:**
```yaml
# Audit streaming configuration (via Azure DevOps REST API or UI):
# Organization Settings > Auditing > Streams > New Stream
#
# Stream 1: Azure Monitor (Log Analytics)
# - Workspace ID: /subscriptions/.../workspaces/security-logs
# - Enables: KQL queries, Sentinel integration, alerting
#
# Stream 2: Splunk HEC
# - URL: https://splunk.mycompany.com:8088/services/collector
# - Token: $(SPLUNK_HEC_TOKEN)

# Example KQL alert in Azure Monitor for suspicious activity:
# AzureDevOpsAuditing
# | where OperationName == "Security.ModifyPermission"
# | where Data contains "Production"
# | where TimeGenerated > ago(1h)
# | project TimeGenerated, ActorDisplayName, OperationName, Data
# | where ActorDisplayName !in ("DevOps-Admin", "Release-Bot")
# -> Alert: "Unauthorized production permission change detected"

# Key events to monitor:
# - Git.RefUpdateBatch (force push to protected branch)
# - Security.ModifyPermission (permission escalation)  
# - Release.ApprovalsComplete (production approval)
# - ServiceEndpoint.Create (new service connection)
# - Library.VariableGroupModified (secret changed)
```

---

### Q60. How do you integrate SonarQube into Azure Pipelines as a quality gate?

**Answer:** SonarQube integration requires four steps: Prepare (configure SonarQube connection and project), Build (compile with SonarQube scanner hooks enabled), Analyze (collect and send metrics), and Publish/QualityGate (poll SonarQube until analysis completes and evaluate the quality gate). If the quality gate status is "ERROR" (e.g., coverage dropped below threshold, new bugs introduced, duplications exceeded), the `SonarQubePublish@5` task marks the pipeline as failed. The service connection stores the SonarQube URL and authentication token.

❌ **Violates:**
```yaml
# Running SonarQube but not failing the pipeline on quality gate failure
steps:
  - task: SonarQubePrepare@5
    inputs: { SonarQube: 'SQ-Connection', scannerMode: 'MSBuild' }
  - task: DotNetCoreCLI@2
    inputs: { command: build }
  - task: SonarQubeAnalyze@5
  # Missing SonarQubePublish — never checks quality gate, always passes
```

✅ **Satisfies:**
```yaml
steps:
  # Step 1: Prepare — must be BEFORE build
  - task: SonarQubePrepare@5
    displayName: 'SonarQube: Prepare'
    inputs:
      SonarQube: 'SonarQube-ServiceConnection'
      scannerMode: 'MSBuild'
      projectKey: 'MyCompany_MyApp'
      projectName: 'MyApp'
      extraProperties: |
        sonar.cs.opencover.reportsPaths=$(Agent.TempDirectory)/**/coverage.opencover.xml
        sonar.cs.vstest.reportsPaths=$(Agent.TempDirectory)/**/*.trx
        sonar.exclusions=**/Migrations/**,**/wwwroot/**
        sonar.coverage.exclusions=**/*Tests*/**,**/Program.cs

  # Step 2: Build with SonarQube hooks
  - task: DotNetCoreCLI@2
    inputs:
      command: build
      arguments: '--configuration Release'

  # Step 3: Test with coverage (data consumed by SonarQube)
  - task: DotNetCoreCLI@2
    inputs:
      command: test
      arguments: '--collect "XPlat Code Coverage" --logger trx'
      publishTestResults: true

  # Step 4: Analyze
  - task: SonarQubeAnalyze@5
    displayName: 'SonarQube: Analyze'

  # Step 5: Publish and check quality gate
  - task: SonarQubePublish@5
    displayName: 'SonarQube: Quality Gate'
    inputs:
      pollingTimeoutSec: '300'
      # Fails pipeline if quality gate status = ERROR
      # Quality gate conditions: coverage >= 80%, 0 new bugs, 0 new vulnerabilities
```

> 📚 Reference: [Azure Pipelines Security](https://docs.microsoft.com/en-us/azure/devops/pipelines/security/overview)
> 📚 Medium: [Securing Azure DevOps Pipelines — Secrets, OIDC, and Protected Resources](https://medium.com/securing-azure-devops-pipelines)

---

## Section 7 — Testing in Pipelines

### Q61. How do you run and publish unit test results in Azure Pipelines?

**Answer:** Unit tests in .NET run via `dotnet test` with the `--logger trx` flag to produce TRX (Visual Studio test results) files. The `publishTestResults: true` shortcut in `DotNetCoreCLI@2` or the separate `PublishTestResults@2` task uploads results to Azure DevOps, where they appear in the Tests tab with pass/fail/skipped counts, failure messages, and trend history. Setting `failTaskOnFailedTests: true` ensures the pipeline step fails (and thus the build fails) when any test fails — without this flag, `dotnet test` exit code 1 might be suppressed.

❌ **Violates:**
```yaml
# Tests run but results not published — failures invisible in Azure DevOps UI
# No trend tracking, no failure details, no flaky test detection
steps:
  - script: dotnet test
    continueOnError: true   # swallows test failures — build always green!
```

✅ **Satisfies:**
```yaml
steps:
  - task: DotNetCoreCLI@2
    displayName: 'Run Unit Tests'
    inputs:
      command: test
      projects: '**/*UnitTests.csproj'
      arguments: >
        --no-build
        --configuration $(buildConfiguration)
        --logger "trx;LogFileName=unit-tests.trx"
        --logger "console;verbosity=normal"
        -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura
      publishTestResults: true          # publishes .trx to Azure DevOps Tests tab
      failTaskOnFailedTests: true       # pipeline fails if any test fails

  # Or using explicit PublishTestResults task:
  - task: PublishTestResults@2
    displayName: 'Publish Test Results'
    condition: always()   # publish even if tests failed (to see what failed)
    inputs:
      testResultsFormat: 'VSTest'
      testResultsFiles: '**/unit-tests.trx'
      mergeTestResults: true
      testRunTitle: 'Unit Tests — $(Build.SourceBranchName)'
      failTaskOnFailedTests: true
```

---

### Q62. How do you measure and enforce code coverage in Azure Pipelines?

**Answer:** Code coverage measures what percentage of production code is executed by tests. In .NET, `--collect "XPlat Code Coverage"` instruments assemblies during test execution, and Coverlet generates the coverage report. `ReportGenerator` converts the raw XML to HTML and Cobertura formats. `PublishCodeCoverageResults@2` uploads to Azure DevOps where it appears in the Code Coverage tab. A minimum coverage threshold can be set — if coverage drops below (e.g., 80%), the pipeline fails, preventing regression in test coverage over time.

❌ **Violates:**
```yaml
# No coverage collection — cannot measure what code is tested
# Team claims "good coverage" but has no data to back it up
steps:
  - script: dotnet test --logger trx
  # No --collect flag, no threshold, no published results
```

✅ **Satisfies:**
```yaml
steps:
  - task: DotNetCoreCLI@2
    displayName: 'Test with Coverage'
    inputs:
      command: test
      projects: '**/*Tests.csproj'
      arguments: >
        --no-build
        --configuration Release
        --collect "XPlat Code Coverage"
        --results-directory $(Agent.TempDirectory)
        -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=cobertura
      publishTestResults: true

  # Convert coverage to multiple formats + generate HTML report
  - task: reportgenerator@5
    displayName: 'Generate Coverage Report'
    inputs:
      reports: '$(Agent.TempDirectory)/**/coverage.cobertura.xml'
      targetdir: '$(Build.ArtifactStagingDirectory)/coverage'
      reporttypes: 'HtmlInline_AzurePipelines;Cobertura;Badges'
      assemblyfilters: '-*.Tests;-*.Migrations'

  # Publish to Azure DevOps (appears in Code Coverage tab)
  - task: PublishCodeCoverageResults@2
    displayName: 'Publish Coverage Results'
    inputs:
      summaryFileLocation: '$(Build.ArtifactStagingDirectory)/coverage/Cobertura.xml'
      reportDirectory: '$(Build.ArtifactStagingDirectory)/coverage'
      failIfCoverageEmpty: true

  # Enforce minimum coverage threshold
  - task: BuildQualityChecks@8
    displayName: 'Enforce Coverage Threshold'
    inputs:
      checkCoverage: true
      coverageType: 'lines'
      coverageThreshold: 80      # fail if line coverage < 80%
      forceNewBaseline: false
```

---

### Q63. How do you run integration tests using a Docker service container in Azure Pipelines?

**Answer:** Service containers are Docker containers that run alongside a pipeline job, providing services like SQL Server, Redis, or RabbitMQ for integration tests without external dependencies. They are defined under `services:` in the job definition and accessible by the container name as hostname. The containers start before the job steps and are stopped/removed after. This enables fully isolated, repeatable integration tests that don't rely on shared test environments.

❌ **Violates:**
```yaml
# Integration tests pointing to shared dev SQL Server
# Tests pollute each other's data, fail when dev team is working, timing-dependent
jobs:
  - job: IntegrationTest
    steps:
      - script: |
          export ConnectionStrings__Default="Server=dev-sql.company.com;..."
          dotnet test tests/Integration.Tests.csproj
          # Shared server: flaky, not isolated, breaks when dev DB is busy
```

✅ **Satisfies:**
```yaml
jobs:
  - job: IntegrationTests
    displayName: 'Integration Tests (SQL + Redis)'
    services:
      # SQL Server container — accessible as 'sqlserver' hostname
      sqlserver:
        image: mcr.microsoft.com/mssql/server:2022-latest
        env:
          ACCEPT_EULA: 'Y'
          SA_PASSWORD: 'Test!Password123'
        ports:
          - 1433:1433
        options: --health-cmd "/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'Test!Password123' -Q 'SELECT 1'"

      # Redis container
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - task: DotNetCoreCLI@2
        displayName: 'Run Integration Tests'
        inputs:
          command: test
          projects: 'tests/Integration.Tests/Integration.Tests.csproj'
          arguments: '--logger trx'
          publishTestResults: true
        env:
          # Tests use these env vars — containers accessible by service name
          ConnectionStrings__Default: 'Server=sqlserver,1433;User Id=sa;Password=Test!Password123;Database=TestDb;TrustServerCertificate=True'
          ConnectionStrings__Redis: 'redis:6379'
```

---

### Q64. How do you run Playwright E2E tests in Azure Pipelines against a staging environment?

**Answer:** End-to-end tests with Playwright run headlessly in CI against the deployed staging application. The pipeline deploys to staging first, then runs Playwright tests in a separate job. Playwright requires browser binaries (`pwsh -c "npx playwright install --with-deps chromium"`) on the agent. On failure, Playwright captures screenshots and traces that are published as pipeline artifacts for debugging. Using `condition: always()` on the artifact publish step ensures results are uploaded even when tests fail.

❌ **Violates:**
```yaml
# E2E tests running locally only, never in CI
# "It works on my machine" — cannot detect regressions automatically
# Manual testing before every release = slow, error-prone, incomplete
```

✅ **Satisfies:**
```yaml
stages:
  - stage: E2ETests
    dependsOn: DeployStaging
    jobs:
      - job: PlaywrightTests
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - task: NodeTool@0
            inputs:
              versionSpec: '20.x'

          - script: npm ci
            displayName: 'Install dependencies'
            workingDirectory: e2e

          - script: npx playwright install --with-deps chromium
            displayName: 'Install Playwright browsers'
            workingDirectory: e2e

          - script: npx playwright test --reporter=html,junit
            displayName: 'Run Playwright E2E Tests'
            workingDirectory: e2e
            env:
              BASE_URL: 'https://myapp-staging.azurewebsites.net'
              TEST_USER_EMAIL: $(E2E_USER_EMAIL)         # from variable group
              TEST_USER_PASSWORD: $(E2E_USER_PASSWORD)
            continueOnError: true   # publish results even on failure

          # Publish JUnit results to Tests tab
          - task: PublishTestResults@2
            condition: always()
            inputs:
              testResultsFormat: 'JUnit'
              testResultsFiles: 'e2e/playwright-results.xml'
              testRunTitle: 'E2E Tests — Staging'
              failTaskOnFailedTests: true

          # Publish HTML report + screenshots as artifact
          - task: PublishPipelineArtifact@1
            condition: always()
            inputs:
              artifactName: 'playwright-report'
              targetPath: 'e2e/playwright-report'
```

---

### Q65. How do test results appear in Azure DevOps and how do you detect flaky tests?

**Answer:** Published test results appear in the pipeline run's Tests tab, showing pass/fail/skipped counts, individual test details, failure messages and stack traces, and historical trend charts. Azure DevOps automatically tracks test history across builds and flags tests as "flaky" when they inconsistently pass and fail across runs without code changes. The Tests Analytics view in Azure Boards provides trend charts, failure rate by test, and MTTF (Mean Time To Failure). Flaky tests should be quarantined (marked as quarantined in Azure Test Plans) to prevent them from blocking CI while being investigated.

❌ **Violates:**
```yaml
# Tests published but no trend analysis, no flaky detection
# Team doesn't know that 5 tests fail intermittently 30% of the time
# Developers re-run pipelines to "get a green build" masking real issues
```

✅ **Satisfies:**
```yaml
steps:
  - task: DotNetCoreCLI@2
    inputs:
      command: test
      arguments: '--logger trx --logger "console;verbosity=minimal"'
      publishTestResults: true

  # Azure DevOps automatically:
  # - Tracks pass/fail history per test across runs
  # - Flags tests as flaky (inconsistent results)
  # - Shows trend: pass rate over last 14 days
  # - Identifies slowest tests (duration trend)

  # To enable retry for potentially flaky tests:
  - task: DotNetCoreCLI@2
    inputs:
      command: test
      arguments: >
        --logger trx
        -- NUnit.NumberOfTestWorkers=4
        RunConfiguration.MaxCpuCount=0
```

```csharp
// Mark a known-flaky test in code while investigating:
[TestMethod]
[Ignore("Flaky: intermittently fails in CI, tracked in AB#5678")]
public async Task SomeIntegrationTest_IsFlaky() { ... }

// Or use Azure Test Plans to quarantine:
// Test Plans > Test Cases > find test > Set outcome: Quarantined
// Quarantined tests run but don't block the build
```

---

### Q66. How do you run performance tests in a CI/CD pipeline?

**Answer:** Performance tests (load tests) validate that the application meets latency and throughput requirements after deployment to staging. Tools like k6 (JavaScript-based, YAML-friendly) or NBomber (.NET-native) run against the staging environment and fail the pipeline if p95 latency exceeds a threshold or error rate exceeds a percentage. Performance tests run after E2E tests and before production approval, preventing performance regressions from reaching production.

❌ **Violates:**
```yaml
# No performance tests — performance regressions discovered by users
# New database query added without index: response time increases 10x
# First indication: PagerDuty alert at 2am after production deploy
```

✅ **Satisfies:**
```yaml
# k6 performance test script: k6/load-test.js
# export default function() {
#   const res = http.get(`${__ENV.BASE_URL}/api/products`);
#   check(res, { 'status 200': (r) => r.status === 200 });
#   sleep(1);
# }
# export const options = {
#   vus: 50, duration: '2m',
#   thresholds: {
#     'http_req_duration': ['p(95)<500'],   // 95th percentile < 500ms
#     'http_req_failed': ['rate<0.01'],     // error rate < 1%
#   }
# };

- stage: PerformanceTests
  dependsOn: E2ETests
  jobs:
    - job: K6LoadTest
      steps:
        - script: |
            sudo apt-get install -y k6
          displayName: 'Install k6'

        - script: |
            k6 run \
              --out json=k6-results.json \
              --env BASE_URL=https://myapp-staging.azurewebsites.net \
              k6/load-test.js
          displayName: 'Run k6 Load Test'
          # k6 exits with code 1 if thresholds are breached — fails the step

        - task: PublishPipelineArtifact@1
          condition: always()
          inputs:
            artifactName: 'k6-results'
            targetPath: 'k6-results.json'
```

---

### Q67. How do you integrate SAST and DAST security scanning into pipelines?

**Answer:** SAST (Static Application Security Testing) analyzes source code without executing it — SonarQube, Checkmarx, and Semgrep are common tools. DAST (Dynamic Application Security Testing) tests the running application by sending attack payloads — OWASP ZAP is the standard open-source tool. A complete security testing pipeline runs SAST during build (no deployment needed) and DAST against the deployed staging environment. Both should fail the pipeline on high/critical findings.

❌ **Violates:**
```yaml
# No security scanning — SQL injection and XSS vulnerabilities ship to production
# Security audit happens quarterly, by which point dozens of vulnerabilities exist
# Compliance certifications require automated security scanning
```

✅ **Satisfies:**
```yaml
stages:
  - stage: SAST
    jobs:
      - job: StaticAnalysis
        steps:
          # SonarQube SAST (see Q60 for full setup)
          - task: SonarQubePrepare@5
            inputs: { SonarQube: 'SonarQube-SC', scannerMode: 'MSBuild', projectKey: 'myapp' }
          - task: DotNetCoreCLI@2
            inputs: { command: build }
          - task: SonarQubeAnalyze@5
          - task: SonarQubePublish@5   # fails on quality gate

          # Semgrep for additional SAST rules
          - script: |
              pip install semgrep
              semgrep --config=p/csharp --config=p/owasp-top-ten \
                --error --json --output semgrep-results.json .
            displayName: 'Semgrep SAST'

  - stage: DAST
    dependsOn: DeployStaging
    jobs:
      - job: ZapScan
        steps:
          # OWASP ZAP baseline scan against deployed staging
          - script: |
              docker run --rm \
                -v $(Build.ArtifactStagingDirectory):/zap/wrk:rw \
                ghcr.io/zaproxy/zaproxy:stable \
                zap-baseline.py \
                -t https://myapp-staging.azurewebsites.net \
                -r zap-report.html \
                -x zap-report.xml \
                --fail-on-warn true    # fail on warnings
            displayName: 'OWASP ZAP Baseline Scan'

          - task: PublishPipelineArtifact@1
            condition: always()
            inputs:
              artifactName: 'security-reports'
              targetPath: '$(Build.ArtifactStagingDirectory)'
```

---

### Q68. How do you handle flaky tests — quarantine, retry, and stabilization strategies?

**Answer:** Flaky tests (tests that intermittently pass/fail without code changes) erode trust in the test suite and cause developers to re-run pipelines instead of fixing root causes. Strategies: `dotnet test --retry-failed-tests N` retries failed tests up to N times (available in vstest); Azure Test Plans quarantine marks tests as non-blocking while tracked; `[Flaky]` attributes (xUnit trait, NUnit category) allow filtering them from CI while fixing. Root causes include timing dependencies (use `WaitUntil` not `Thread.Sleep`), shared state (isolate test data), and environment assumptions (use container services).

❌ **Violates:**
```yaml
# Re-running entire pipeline to "get a green build"
# Team knows 3 tests fail 20% of the time
# Response: click "Re-run failed jobs" and hope it passes this time
# Technical debt accumulates, trust in tests erodes
```

✅ **Satisfies:**
```yaml
# Retry in pipeline for truly intermittent tests (last resort)
steps:
  - task: DotNetCoreCLI@2
    inputs:
      command: test
      arguments: >
        --logger trx
        -- RunConfiguration.TreatNoTestsAsError=true
        RunConfiguration.RetryOnFailure=true
        RunConfiguration.MaxRetryCount=2    # retry failed tests up to 2 times
```

```csharp
// Proper fix: eliminate timing dependency
// BAD:
Thread.Sleep(2000);
Assert.True(result.IsComplete);

// GOOD: poll with timeout
await Polly.Policy
    .HandleResult<bool>(r => !r)
    .WaitAndRetryAsync(10, _ => TimeSpan.FromMilliseconds(200))
    .ExecuteAsync(() => Task.FromResult(result.IsComplete));

// Mark quarantined test in xUnit:
[Trait("Category", "Quarantined")]
[Fact]
public async Task FlickeringTest_TrackedInAB1234() { }
// Then exclude from CI: dotnet test --filter "Category!=Quarantined"
```

---

### Q69. How do you implement contract testing with Pact in Azure Pipelines?

**Answer:** Contract testing verifies that a consumer's expectations of a provider API are met without deploying both services simultaneously. Pact generates a contract (pact file) from consumer tests, publishes it to Pact Broker, and the provider verifies the contract against its own implementation in a separate pipeline. This catches API breaking changes before integration environment deployment. In Azure Pipelines, consumer tests publish contracts to Pact Broker, and provider pipelines include a verification step that fails if the contract is broken.

❌ **Violates:**
```yaml
# No contract testing — API breaking changes discovered in integration environment
# Consumer team deploys, integration tests fail, 2-day debugging session
# "Who changed the /api/orders response schema?" investigation begins
```

✅ **Satisfies:**
```yaml
# Consumer pipeline (e.g., Frontend service)
steps:
  - task: DotNetCoreCLI@2
    displayName: 'Run Pact Consumer Tests'
    inputs:
      command: test
      projects: 'tests/Consumer.Pact.Tests/Consumer.Pact.Tests.csproj'
      # Tests generate pact file: pacts/frontend-orderservice.json

  - script: |
      # Publish pact to Pact Broker
      dotnet pact-broker publish \
        ./pacts \
        --broker-base-url $(PACT_BROKER_URL) \
        --broker-token $(PACT_BROKER_TOKEN) \
        --consumer-app-version $(Build.BuildNumber) \
        --tag $(Build.SourceBranchName)
    displayName: 'Publish Pacts to Broker'
```

```yaml
# Provider pipeline (e.g., OrderService)
steps:
  - task: DotNetCoreCLI@2
    displayName: 'Verify Pact Contracts'
    inputs:
      command: test
      projects: 'tests/Provider.Pact.Tests/Provider.Pact.Tests.csproj'
    env:
      PACT_BROKER_URL: $(PACT_BROKER_URL)
      PACT_BROKER_TOKEN: $(PACT_BROKER_TOKEN)
      PROVIDER_VERSION: $(Build.BuildNumber)
      PROVIDER_BRANCH: $(Build.SourceBranchName)
      # Fails if any consumer contract is not satisfied
```

---

### Q70. What test metrics should you track and how do you report them from Azure DevOps Analytics?

**Answer:** Key test metrics: pass rate percentage (target > 99%), flaky rate (tests failing intermittently, target < 1%), test execution time trend (detect slowdowns), code coverage percentage (target > 80%), MTTF (Mean Time To Failure — how long a healthy test run lasts before a failure), and defect escape rate (bugs found in production vs pre-production). Azure DevOps Analytics provides built-in Test Analytics and Flaky Test detection. Custom Power BI dashboards consume the Analytics OData endpoint for cross-pipeline reporting.

❌ **Violates:**
```yaml
# Teams flying blind — no metrics, no trend visibility
# Management asks "is quality improving?" and nobody knows
# Decision to reduce test suite because "tests are too slow" with no data
```

✅ **Satisfies:**
```yaml
# Built-in Azure DevOps Analytics (no configuration needed):
# Pipeline > Tests tab: shows pass rate, duration, failures for this run
# Pipeline > Analytics tab: trend over 14 runs
# Project > Test Plans > Analytics: flaky test report

# Custom OData query for Power BI:
# https://analytics.dev.azure.com/{org}/{project}/_odata/v3.0-preview/TestResultsDaily
# ?$apply=filter(Pipeline/PipelineName eq 'MyApp-CI' and DateSK gt 20241101)
# /groupby((DateSK, TestSK), aggregate(ResultCount with sum as Total,
#   PassedCount with sum as Passed, FailedCount with sum as Failed))

# Add Azure Boards widget to team dashboard:
# - Test Results Trend widget: pass rate over last 30 builds
# - Code Coverage widget: coverage percentage gauge
# - Test Failures widget: top 10 failing tests this week

# Key thresholds to alert on:
# - Pass rate < 95%: investigate immediately
# - Coverage drop > 5% in single PR: block merge
# - Any test > 60 seconds: performance investigation
# - Flaky rate > 2%: quarantine and fix sprint
```

> 📚 Reference: [Azure Pipelines Test Reporting](https://docs.microsoft.com/en-us/azure/devops/pipelines/test/review-continuous-test-results-after-build)
> 📚 Medium: [Complete Testing Strategy for .NET Applications in Azure DevOps](https://medium.com/testing-strategy-azure-devops)

---

## Section 8 — Deployment Strategies

### Q71. What is Blue-Green deployment and how is it implemented with Azure App Service slots?

**Answer:** Blue-Green deployment maintains two identical production environments: Blue (current live) and Green (new version). Traffic serves entirely from Blue while Green is deployed and validated. A DNS/load balancer switch flips all traffic to Green instantly, making Blue the standby for rollback. Azure App Service implements this natively with deployment slots — "staging" slot (Green) receives the new deployment, smoke tests validate it, and a slot swap (instant, zero-downtime) makes it the "production" slot. The previous production becomes the new staging slot, enabling immediate rollback by swapping again.

❌ **Violates:**
```yaml
# Direct in-place deployment — downtime during deployment, no instant rollback
steps:
  - task: AzureWebApp@1
    inputs:
      appName: 'myapp-prod'
      package: '$(Pipeline.Workspace)/webapp/**/*.zip'
      # App restarts in place: 30-60 seconds downtime
      # No previous version available: rollback requires re-deploy (10+ minutes)
```

✅ **Satisfies:**
```yaml
steps:
  # Blue-Green with App Service slots
  - task: AzureWebApp@1
    displayName: 'Deploy to GREEN (staging slot)'
    inputs:
      azureSubscription: 'Prod-SC'
      appName: 'myapp-prod'
      deployToSlotOrASE: true
      resourceGroupName: 'rg-production'
      slotName: 'staging'          # Green slot
      package: '$(Pipeline.Workspace)/webapp/**/*.zip'

  - script: |
      # Validate Green slot before swap
      response=$(curl -s -o /dev/null -w "%{http_code}" \
        https://myapp-prod-staging.azurewebsites.net/health)
      [ "$response" = "200" ] || (echo "Green slot unhealthy: $response" && exit 1)
    displayName: 'Validate GREEN slot'

  - task: AzureAppServiceManage@0
    displayName: 'SWAP: Green → Blue (zero downtime)'
    inputs:
      azureSubscription: 'Prod-SC'
      Action: 'Swap Slots'
      WebAppName: 'myapp-prod'
      ResourceGroupName: 'rg-production'
      SourceSlot: 'staging'
      SwapWithProduction: true
      # Instant: Blue is now live; old Blue is now in staging (instant rollback available)

  # Rollback: swap again to restore old Blue
  # - task: AzureAppServiceManage@0
  #   inputs:
  #     Action: 'Swap Slots'
  #     SourceSlot: 'staging'
  #     SwapWithProduction: true
```

---

### Q72. What is Canary deployment and how do you implement it with Azure Traffic Manager?

**Answer:** Canary deployment routes a small percentage of real traffic (5-10%) to the new version while the majority continues on the current version. Metrics (error rate, latency, conversion rate) are monitored for the canary cohort. If metrics look good, traffic shifts to 50%, then 100%. If metrics degrade, the canary is rolled back by removing it from the traffic distribution. Azure Traffic Manager with weighted routing implements canary at the DNS level; Azure Front Door and Application Gateway support header/cookie-based canary routing for more precision.

❌ **Violates:**
```yaml
# Deploying 100% of traffic to new version simultaneously
# Any regression affects all users immediately
# Rollback requires re-deployment under full production load
```

✅ **Satisfies:**
```yaml
# Canary deployment pipeline — phased traffic shift
stages:
  - stage: CanaryDeploy
    jobs:
      - deployment: Canary
        environment: 'Production-Canary'
        strategy:
          canary:
            increments: [10, 50, 100]   # 10% → validate → 50% → validate → 100%
            deploy:
              steps:
                - task: AzureWebApp@1
                  inputs:
                    appName: 'myapp-prod-canary'   # separate canary slot/instance

            postRouteTraffic:
              steps:
                # After each increment: validate metrics before proceeding
                - task: AzureMonitor@1
                  displayName: 'Check Canary Error Rate'
                  inputs:
                    connectedServiceName: 'Prod-SC'
                    ResourceGroupName: 'rg-production'
                    # Query: requests | where success == false | summarize errorRate=count()*100.0/count()
                    # Fail if error rate > 1%

                - script: |
                    # Check p95 latency via Application Insights query
                    LATENCY=$(az monitor app-insights query \
                      --apps myapp-prod-insights \
                      --analytics-query "requests | summarize percentile(duration,95)" \
                      --query "tables[0].rows[0][0]" -o tsv)
                    [ $(echo "$LATENCY < 500" | bc) -eq 1 ] || exit 1
                  displayName: 'Check p95 Latency < 500ms'

            on:
              failure:
                steps:
                  - script: |
                      # Remove canary from Traffic Manager weight
                      az network traffic-manager endpoint update \
                        --resource-group rg-production \
                        --profile-name myapp-tm \
                        --name canary-endpoint \
                        --type azureEndpoints \
                        --weight 0
                    displayName: 'Rollback: Remove canary traffic'
```

---

### Q73. What is a Rolling deployment strategy and how does it work in Azure Pipelines?

**Answer:** Rolling deployment updates instances in batches rather than all at once, maintaining service availability throughout. `maxSurge` specifies additional instances to create during the roll (0 = no extra capacity), and `maxUnavailable` specifies the maximum instances that can be down simultaneously (25% = at most 25% of instances unavailable at any time). If a batch fails, the deployment stops and the remaining instances keep running the old version. Rolling works well for stateless applications with multiple instances behind a load balancer.

❌ **Violates:**
```yaml
# Stopping all instances before deploying — complete outage during deploy
# 5 instances × 30s restart = 2.5 minutes downtime minimum
strategy:
  runOnce:
    deploy:
      steps:
        - task: StopWebApp   # stop all 5 instances
        - task: Deploy       # deploy to all 5
        - task: StartWebApp  # start all 5
```

✅ **Satisfies:**
```yaml
jobs:
  - deployment: RollingDeploy
    environment:
      name: 'Production'
      resourceType: VirtualMachine    # rolling works with VM-based environments
    strategy:
      rolling:
        maxParallel: 2       # update 2 VMs at a time (rest still serve traffic)
        preDeploy:
          steps:
            - script: |
                # Remove this VM from load balancer before update
                az network lb rule update --name myapp-lb-rule --backend-pool-name new-pool
              displayName: 'Remove VM from LB'
        deploy:
          steps:
            - task: DownloadPipelineArtifact@2
              inputs: { artifactName: 'webapp' }
            - task: IISWebAppDeploymentOnMachineGroup@0
              inputs:
                WebSiteName: 'MyApp'
                Package: '$(Pipeline.Workspace)/webapp/**/*.zip'
        postDeploy:
          steps:
            - script: |
                # Verify health before adding back to LB
                curl -f http://localhost/health || exit 1
              displayName: 'Health check'
            - script: |
                # Re-add to load balancer
                az network lb rule update --name myapp-lb-rule --backend-pool-name prod-pool
              displayName: 'Add VM back to LB'
        on:
          failure:
            steps:
              - script: echo "Rolling deployment failed — partial update in progress"
```

---

### Q74. How do you implement feature flags for safe deployments using Azure App Configuration?

**Answer:** Feature flags decouple code deployment from feature activation. The new code is deployed to production with the flag disabled (dark deployment), then the flag is enabled for internal users first, then beta users, then all users — without any new deployment. Azure App Configuration with the `Microsoft.FeatureManagement` library provides `IFeatureManager.IsEnabledAsync("FeatureName")` for runtime evaluation. Feature filters enable percentage-based rollout, user-targeting, and time-window activation.

❌ **Violates:**
```csharp
// Hard-coded feature gate — requires code change and redeploy to enable/disable
public async Task<IActionResult> GetOrders()
{
    // if (USE_NEW_ORDERS_ENGINE) — compile-time constant, not configurable
    return Ok(await _legacyOrderService.GetOrdersAsync());
}
```

✅ **Satisfies:**
```csharp
// Program.cs — connect to Azure App Configuration
builder.Configuration.AddAzureAppConfiguration(options =>
{
    options.Connect(connectionString)
           .UseFeatureFlags(ff => ff.SetCacheExpiration(TimeSpan.FromMinutes(5)));
});
builder.Services.AddFeatureManagement();

// OrdersController.cs
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IFeatureManager _featureManager;
    private readonly IOrderService _legacyService;
    private readonly INewOrderEngine _newEngine;

    [HttpGet]
    public async Task<IActionResult> GetOrders()
    {
        if (await _featureManager.IsEnabledAsync("NewOrdersEngine"))
            return Ok(await _newEngine.GetOrdersAsync());

        return Ok(await _legacyService.GetOrdersAsync());
    }
}
```

```yaml
# Pipeline: enable feature flag AFTER deploying code (no redeploy)
- stage: EnableFeatureFlag
  dependsOn: DeployProd
  condition: and(succeeded(), eq(variables['EnableNewFeature'], 'true'))
  jobs:
    - job: ToggleFeatureFlag
      steps:
        - task: AzureCLI@2
          inputs:
            azureSubscription: 'Prod-SC'
            scriptType: bash
            inlineScript: |
              az appconfig feature enable \
                --name myapp-appconfig-prod \
                --feature NewOrdersEngine \
                --yes
```

---

### Q75. How do smoke tests work as a deployment gate in Azure Pipelines?

**Answer:** Smoke tests are lightweight automated checks run immediately after deployment to verify the application is alive and basic functionality works — HTTP health endpoints, login flow, critical API routes. They run as a pipeline step after the deployment task and before any approval for the next stage. Failure triggers automatic rollback (slot swap back) without waiting for user reports. Smoke tests should complete within 2-5 minutes: fast enough to catch deployment failures before users notice, comprehensive enough to cover the critical path.

❌ **Violates:**
```yaml
# Deploying without any post-deployment validation
# First indication of broken deploy: user support tickets
# 30 minutes to detect, diagnose, rollback = 30 minutes of user impact
steps:
  - task: AzureWebApp@1
  # No smoke test, no health check, assume it works
```

✅ **Satisfies:**
```yaml
steps:
  - task: AzureWebApp@1
    displayName: 'Deploy to Staging Slot'
    inputs:
      appName: 'myapp-prod'
      deployToSlotOrASE: true
      slotName: 'staging'

  - task: PowerShell@2
    displayName: 'Smoke Tests'
    inputs:
      targetType: inline
      script: |
        $baseUrl = "https://myapp-prod-staging.azurewebsites.net"

        # Test 1: Health endpoint
        $health = Invoke-RestMethod -Uri "$baseUrl/health"
        if ($health.status -ne "Healthy") { throw "Health check failed: $($health.status)" }

        # Test 2: API is responding
        $r = Invoke-WebRequest -Uri "$baseUrl/api/products?page=1" -UseBasicParsing
        if ($r.StatusCode -ne 200) { throw "Products API returned: $($r.StatusCode)" }

        # Test 3: Auth endpoint reachable (not testing credentials)
        $r = Invoke-WebRequest -Uri "$baseUrl/api/auth/ping" -UseBasicParsing
        if ($r.StatusCode -ne 200) { throw "Auth ping failed: $($r.StatusCode)" }

        Write-Host "All smoke tests passed"

  - task: AzureAppServiceManage@0
    displayName: 'Swap to Production (smoke tests passed)'
    inputs:
      Action: 'Swap Slots'
      WebAppName: 'myapp-prod'
      SourceSlot: 'staging'
      SwapWithProduction: true
```

---

### Q76. How do you achieve zero-downtime database migrations using the expand/contract pattern?

**Answer:** The expand/contract pattern (also called parallel-change) enables backward-compatible database migrations by splitting each change into multiple deployments. Expand: add the new column/table as nullable/optional — both old and new app code work. Migrate: backfill data in the new structure. Contract: remove old column once all app code uses the new structure. This allows deploying app changes independently of schema changes and supports instant rollback of the application without schema rollback.

❌ **Violates:**
```yaml
# Rename column in single migration — breaking change
# Migration: ALTER TABLE Orders RENAME COLUMN Amount TO TotalPrice
# Old app code: SELECT Amount FROM Orders -> FAILS immediately
# Rollback requires reverting migration AND app deploy simultaneously
```

✅ **Satisfies:**
```csharp
// STEP 1: Expand migration — add new column, keep old
// Migration 001_AddTotalPrice.cs
migrationBuilder.AddColumn<decimal>("TotalPrice", "Orders", nullable: true);

// STEP 2: App reads from both (tolerant reader)
var amount = order.TotalPrice ?? order.Amount;  // reads new if available, falls back to old

// STEP 3: Backfill migration — populate new column
// Migration 002_BackfillTotalPrice.cs
migrationBuilder.Sql("UPDATE Orders SET TotalPrice = Amount WHERE TotalPrice IS NULL");

// STEP 4: App writes to both columns
order.TotalPrice = value;
order.Amount = value;  // still writes old column

// STEP 5: App reads only from new column (after 100% rollout)
var amount = order.TotalPrice!.Value;

// STEP 6: Contract migration — remove old column
// Migration 003_RemoveAmount.cs (separate PR/deploy)
migrationBuilder.DropColumn("Amount", "Orders");
```

```yaml
# Pipeline runs migrations before app deploy each step
steps:
  - script: ./efbundle --connection "$(DbConnectionString)"
    displayName: 'Run EF Core Migration'
  - task: AzureWebApp@1
    displayName: 'Deploy App'
```

---

### Q77. How do you implement automated rollback based on Azure Monitor metrics?

**Answer:** Automated rollback triggers when post-deployment monitoring detects degradation — error rate spike, latency increase, or exception count exceeding baseline. The pipeline uses Azure Monitor release gates (polling Azure Monitor alert rules) or a custom PowerShell step that queries Application Insights via REST API and fails if thresholds are exceeded. When the post-deployment validation step fails, the `on: failure:` block executes the slot swap rollback, restoring the previous version automatically without human intervention.

❌ **Violates:**
```yaml
# No automated rollback — rely on on-call engineer to notice and respond
# MTTD (Mean Time to Detect): 10-30 minutes (monitoring lag)
# MTTR (Mean Time to Recover): 20-40 minutes (manual investigation + rollback)
# Total user impact: 30-70 minutes
```

✅ **Satisfies:**
```yaml
jobs:
  - deployment: DeployAndValidate
    environment: 'Production'
    strategy:
      runOnce:
        deploy:
          steps:
            - task: AzureWebApp@1
              inputs:
                appName: 'myapp-prod'
                deployToSlotOrASE: true
                slotName: 'staging'

            - task: AzureAppServiceManage@0
              displayName: 'Swap to Production'
              inputs: { Action: 'Swap Slots', SourceSlot: 'staging', SwapWithProduction: true }

        postRouteTraffic:
          steps:
            - script: |
                # Wait for traffic to settle, then check metrics
                sleep 120
                # Query Application Insights for error rate in last 2 minutes
                ERROR_RATE=$(az monitor app-insights query \
                  --apps myapp-prod-insights \
                  --analytics-query "requests | where timestamp > ago(2m) | summarize errorRate=todouble(countif(success==false))/count()*100" \
                  --query "tables[0].rows[0][0]" -o tsv)

                echo "Error rate: $ERROR_RATE%"
                python3 -c "import sys; sys.exit(1 if float('$ERROR_RATE') > 2.0 else 0)"
              displayName: 'Validate error rate < 2%'

        on:
          failure:
            steps:
              - task: AzureAppServiceManage@0
                displayName: 'AUTO-ROLLBACK: Swap back to previous'
                inputs:
                  azureSubscription: 'Prod-SC'
                  Action: 'Swap Slots'
                  WebAppName: 'myapp-prod'
                  ResourceGroupName: 'rg-production'
                  SourceSlot: 'staging'
                  SwapWithProduction: true
                  # Brings previous version back to production in ~10 seconds
```

---

### Q78. What is GitOps and how does it compare to traditional push-based CD pipelines?

**Answer:** GitOps treats Git as the single source of truth for infrastructure and application desired state. Tools like ArgoCD (Kubernetes) or Flux watch a Git repository and continuously reconcile the actual cluster state to match the declared state in Git. Push-based CD (Azure Pipelines) actively deploys by pushing changes to environments. GitOps is pull-based: the environment pulls its desired state from Git. GitOps provides stronger audit trails (every state change is a Git commit), natural rollback (revert the commit), and drift detection (the tool alerts if someone manually changes the cluster bypassing Git).

❌ **Violates:**
```yaml
# Push-based: pipeline has write access to production Kubernetes cluster
# Security risk: compromised pipeline can modify production directly
# Drift: someone uses kubectl apply manually and pipeline state diverges
steps:
  - script: kubectl apply -f k8s/
    env:
      KUBECONFIG: $(KUBECONFIG_SECRET)   # pipeline has full cluster access
```

✅ **Satisfies:**
```yaml
# GitOps workflow:
# 1. CI pipeline builds image and pushes to registry
# 2. CI pipeline updates the image tag in a separate GitOps repo (git commit)
# 3. ArgoCD (running in cluster) detects the commit and syncs

# CI Pipeline step: update GitOps repo (NOT deploying directly)
steps:
  - script: |
      # After building and pushing image:
      IMAGE_TAG="$(Build.BuildNumber)"

      # Clone the GitOps config repo
      git clone https://dev.azure.com/org/project/_git/k8s-config
      cd k8s-config

      # Update image tag using kustomize or yq
      yq e ".images[0].newTag = \"$IMAGE_TAG\"" -i apps/myapp/kustomization.yaml

      git config user.email "ci-bot@company.com"
      git config user.name "CI Bot"
      git commit -am "chore: bump myapp to $IMAGE_TAG [skip ci]"
      git push
    displayName: 'Update GitOps repo (ArgoCD syncs automatically)'

# ArgoCD then detects the change and applies it to the cluster
# Rollback = revert the GitOps repo commit (git revert or manual)
# Drift detection: ArgoCD UI shows "OutOfSync" if manual changes made
```

---

### Q79. How do you use Terraform or Bicep in a CI/CD pipeline with approval gates?

**Answer:** Infrastructure as Code (Terraform or Bicep) in CI/CD follows a plan-then-apply pattern. In the CI/Build stage, run `terraform plan` or `bicep build` to produce a plan artifact showing what changes will be made — this is a dry run with no actual changes. The plan output is reviewed by infrastructure engineers before approving. In the CD stage (after approval), `terraform apply` executes the plan against the target environment. Terraform state is stored in Azure Blob Storage with state locking to prevent concurrent applies.

❌ **Violates:**
```yaml
# terraform apply without plan review — dangerous for production infrastructure
steps:
  - script: |
      terraform init
      terraform apply -auto-approve   # no plan, no review, immediate changes
      # Could accidentally delete databases, change security groups, modify VNets
```

✅ **Satisfies:**
```yaml
stages:
  - stage: TerraformPlan
    jobs:
      - job: Plan
        steps:
          - task: TerraformInstaller@1
            inputs: { terraformVersion: '1.6.x' }

          - task: TerraformTaskV4@4
            displayName: 'Terraform Init'
            inputs:
              provider: azurerm
              command: init
              backendServiceArm: 'Prod-SC'
              backendAzureRmResourceGroupName: 'rg-tfstate'
              backendAzureRmStorageAccountName: 'mytfstatestorage'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: 'prod.terraform.tfstate'

          - task: TerraformTaskV4@4
            displayName: 'Terraform Plan'
            inputs:
              provider: azurerm
              command: plan
              environmentServiceNameAzureRM: 'Prod-SC'
              commandOptions: '-out=$(Build.ArtifactStagingDirectory)/tfplan'

          - task: PublishPipelineArtifact@1
            inputs:
              artifactName: 'tfplan'
              targetPath: '$(Build.ArtifactStagingDirectory)/tfplan'

  - stage: TerraformApply
    dependsOn: TerraformPlan
    # Manual approval gate on 'Production-Infra' environment before apply
    jobs:
      - deployment: Apply
        environment: 'Production-Infra'   # has approval gate
        strategy:
          runOnce:
            deploy:
              steps:
                - task: DownloadPipelineArtifact@2
                  inputs: { artifactName: 'tfplan' }

                - task: TerraformTaskV4@4
                  displayName: 'Terraform Apply (approved plan)'
                  inputs:
                    provider: azurerm
                    command: apply
                    environmentServiceNameAzureRM: 'Prod-SC'
                    commandOptions: '$(Pipeline.Workspace)/tfplan/tfplan'
```

---

### Q80. What are deployment rings and how do progressive exposure deployments work?

**Answer:** Deployment rings (also called progressive exposure) roll out changes to increasingly larger user populations: Ring 0 (internal employees, ~50 users), Ring 1 (beta/early adopters, ~5% of users), Ring 2 (broad availability, ~50%), Ring 3 (general availability, 100%). Each ring is a real production environment. Between rings, metrics are monitored and the deployment is either promoted or rolled back. Feature flags control ring membership per user. This is used by large teams (Windows, Office 365, Azure) to safely deploy to millions of users.

❌ **Violates:**
```yaml
# Big-bang deployment: all users see new version simultaneously
# 1 million users hit the new checkout flow at once
# Bug in checkout discovered: $2M in lost sales in first 30 minutes
# Rollback affects all 1M users
```

✅ **Satisfies:**
```yaml
stages:
  - stage: Ring0_Internal
    jobs:
      - deployment: Internal
        environment: 'Ring0-Internal'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureWebApp@1
                - script: |
                    # Enable feature flag for internal employees only
                    az appconfig feature enable \
                      --feature NewCheckout \
                      --filter-name TargetingFilter \
                      --filter-parameters '{"Audience":{"Users":["@company.com"]}}'

  - stage: Ring1_Beta
    dependsOn: Ring0_Internal
    condition: and(succeeded(), eq(variables['PromoteToRing1'], 'true'))
    jobs:
      - deployment: Beta
        environment: 'Ring1-Beta'    # approval gate here
        strategy:
          runOnce:
            deploy:
              steps:
                - script: |
                    # Expand feature flag to 5% of all users
                    az appconfig feature enable \
                      --feature NewCheckout \
                      --filter-name PercentageFilter \
                      --filter-parameters '{"Value":"5"}'

  - stage: Ring2_Broad
    dependsOn: Ring1_Beta
    condition: and(succeeded(), eq(variables['PromoteToRing2'], 'true'))
    jobs:
      - deployment: Broad
        environment: 'Ring2-GA'
        strategy:
          runOnce:
            deploy:
              steps:
                - script: |
                    az appconfig feature enable \
                      --feature NewCheckout \
                      --filter-name PercentageFilter \
                      --filter-parameters '{"Value":"100"}'
```

> 📚 Reference: [Deployment Strategies — Azure Architecture Center](https://docs.microsoft.com/en-us/azure/architecture/framework/devops/release-engineering-cd)
> 📚 Medium: [Safe Deployments at Scale with Feature Flags and Deployment Rings](https://medium.com/safe-deployments-feature-flags)

---

## Section 9 — Azure Boards & Agile

### Q81. What is the Azure Boards work item hierarchy and how does it support portfolio planning?

**Answer:** Azure Boards work items follow a hierarchy: Epic → Feature → User Story → Task, with Bugs and Issues tracked separately (or mapped alongside Stories). Epics represent large business initiatives spanning multiple sprints (e.g., "Payment System Overhaul"). Features are deliverable chunks of an Epic (e.g., "Credit Card Processing"). User Stories are user-facing requirements completable in one sprint. Tasks are technical sub-items within a Story. Portfolio planning uses the rollup view to see Story completion percentages bubbling up to Features and Epics, enabling leadership visibility into initiative progress.

❌ **Violates:**
```yaml
# Flat work item structure — all items as Tasks with no hierarchy
# Cannot answer: "How far along is the Payment Overhaul initiative?"
# No Epic/Feature = no portfolio view, no cross-team coordination
Tasks:
  - "Add credit card form"
  - "Connect Stripe API"
  - "Write unit tests"
  - "Deploy to staging"
  # No grouping, no parent-child relationships, no progress rollup
```

✅ **Satisfies:**
```yaml
# Proper hierarchy in Azure Boards:
Epic: "Payment System Overhaul"              # Initiative level, 2 quarters
  Feature: "Credit Card Processing"          # Deliverable, Sprint 1-2
    Story: "User can enter credit card"      # User-facing, Sprint 1 (5 SP)
      Task: "Design card form UI"            # Technical (3h)
      Task: "Implement Stripe.js integration"# Technical (5h)
      Task: "Write unit tests"               # Technical (2h)
    Story: "User sees payment confirmation"  # Sprint 2 (3 SP)
  Feature: "Saved Payment Methods"           # Deliverable, Sprint 3-4
    Story: "User can save a card"
    Story: "User can select saved card"

# Portfolio view shows:
# Epic "Payment System Overhaul": 2/5 Features complete (40%)
# Feature "Credit Card Processing": 1/2 Stories complete (50%)
```

---

### Q82. How does sprint planning work in Azure Boards with team capacity?

**Answer:** Sprint planning in Azure Boards involves: setting sprint dates and capacity per team member (hours per day × sprint days × days off), adding Stories from the backlog to the sprint, assigning Stories to team members, and tracking remaining hours on Tasks against each member's capacity. Velocity (average story points completed per sprint) informs how many points to commit in planning. Azure Boards shows capacity bars per team member and warns when assignments exceed capacity, helping teams avoid overcommitment.

❌ **Violates:**
```yaml
# Committing 200 story points when team velocity is 40 SP/sprint
# No capacity planning: team of 5 available 6h/day × 10 days = 300h
# Assigned 450 hours of work → 150 hours unfinished at sprint end
# Sprint goal missed every sprint, burndown shows perpetual underdone state
```

✅ **Satisfies:**
```yaml
# Sprint planning process in Azure Boards:
#
# 1. Set team capacity:
#    Alice: 6h/day, 8 days (2 days off) = 48h sprint capacity
#    Bob:   6h/day, 10 days = 60h
#    Carol: 6h/day, 9 days (1 vacation day) = 54h
#    Total capacity: 162h
#
# 2. Select stories for sprint:
#    Story: "User login" — 5SP, estimated 24h tasks
#    Story: "Product search" — 8SP, estimated 36h tasks
#    Story: "Cart add item" — 3SP, estimated 18h tasks
#    Story: "Checkout flow" — 8SP, estimated 40h tasks
#    Total: 24SP, 118h (72% capacity — reasonable buffer for interruptions)
#
# 3. Assign stories/tasks to team members within capacity limits
# 4. Azure Boards shows capacity bar per person (green = OK, red = over capacity)
# 5. Track daily: remaining hours vs burndown ideal line

# Azure Boards > Sprints > Capacity tab:
# Per team member: Set days off, hours per day
# Capacity per activity: Dev/Testing/Management
```

---

### Q83. How do Kanban boards work in Azure Boards with WIP limits and Definition of Done?

**Answer:** Kanban boards visualize work flowing through columns representing workflow states (e.g., Backlog → Active → Review → Testing → Done). WIP (Work In Progress) limits on each column prevent overloading — if Testing has a limit of 3 and 3 items are there, no new items can move in until one moves out. Definition of Done criteria per column ensure quality gates are met before advancing (e.g., "Code Review" column DoD: "2 approvals, tests passing, no merge conflicts"). Swimlanes separate different work types (expedite, standard, maintenance).

❌ **Violates:**
```yaml
# No WIP limits — 15 stories "In Progress" simultaneously
# Context switching kills productivity: each story takes 3x longer
# No Definition of Done: stories move to "Done" without tests
# Result: everything is "in progress" forever, nothing ships
Columns:
  - To Do: (unlimited)
  - In Progress: (unlimited) ← 15 stories here
  - Done: (unlimited, no DoD check)
```

✅ **Satisfies:**
```yaml
# Kanban board configuration in Azure Boards:
Columns:
  - Backlog:
      WIP Limit: none          # unlimited staging area
  - Active (Development):
      WIP Limit: 4             # max 4 stories in dev simultaneously
      Definition of Done:
        - Code written and unit tests added
        - Feature branch builds successfully
        - Self-reviewed by developer
  - Code Review:
      WIP Limit: 3             # reviewers can handle max 3 at once
      Definition of Done:
        - 2 reviewer approvals
        - All PR comments resolved
        - No merge conflicts
  - Testing:
      WIP Limit: 3
      Definition of Done:
        - Acceptance criteria verified
        - Regression tests passed
        - Test notes documented
  - Done:
      WIP Limit: none

# Swimlanes:
#   🔴 Expedite (P1 bugs): bypasses WIP limits
#   🟡 Standard (normal stories)
#   🔵 Tech Debt / Maintenance

# Blocked flag: drag card to blocked state with reason
# → triggers Slack notification to team lead
```

---

### Q84. How do you link commits and PRs to Azure Boards work items in practice?

**Answer:** Work item linking provides traceability from a requirement to its implementation and deployment. Commit messages with `AB#1234` automatically create a link from the work item to the commit. Branch naming convention `feature/1234-description` triggers auto-linking in some configurations. Pull Requests can require work item links as a branch policy (enforced before merge). When PR is completed, Azure DevOps transitions the linked work item state (e.g., Active → Resolved). This complete chain allows clicking from a production deployment back to the original business requirement.

❌ **Violates:**
```bash
# Commits with no work item reference
git commit -m "fix"
git commit -m "more fixes"
git commit -m "done"
# Cannot answer: "Which release included the fix for customer bug #1234?"
# Cannot answer: "What code changed for this story?"
```

✅ **Satisfies:**
```bash
# Developer workflow:
# 1. Check out work item in Azure Boards (move to Active)
# 2. Create branch with work item reference
git checkout -b feature/1234-user-login-sso

# 3. Commit with AB# reference
git commit -m "feat: implement SSO login with MSAL AB#1234"
git commit -m "test: add unit tests for SSO token validation AB#1234"

# 4. PR title includes AB# reference
# PR: "Feature: SSO Login [AB#1234]"

# 5. PR completion triggers state transition:
# Work item 1234: Active → Resolved (configured in Project Settings)

# Branch policy: require linked work item
# Repos > Branches > main > Branch Policies:
# ✅ Check for linked work items: Required
# Prevents PR merge if no work item is linked

# Query: "What shipped in release 2.4.0?"
# Azure Boards > Queries > Work Items linked to build/commit range
```

---

### Q85. How do queries and dashboards work in Azure Boards?

**Answer:** Azure Boards queries are saved work item searches with conditions, field selections, and sorting — shared across the team or personal. Common queries: active P1 bugs by area, stories in current sprint not yet started, unassigned tasks, items tagged for a specific release. Dashboards compose multiple widgets (velocity chart, burndown, query results, deployment status, code coverage) into a team-specific view. The Analytics service provides velocity, cumulative flow diagrams (CFD), and lead/cycle time data for continuous improvement.

❌ **Violates:**
```yaml
# No saved queries — team manually searches for work items repeatedly
# No dashboard — status meetings require manual data gathering
# "How many bugs are open?" → someone exports to Excel, updates manually
```

✅ **Satisfies:**
```yaml
# Saved query: "Active P1 Bugs in My Area"
# Type: Flat list
# Conditions:
#   Work Item Type = Bug
#   AND State <> Closed
#   AND Severity = 1 - Critical
#   AND Area Path Under = MyTeam
# Columns: ID, Title, Assigned To, State, Created Date, Age

# Saved query: "Sprint Commitment Status"
# Conditions:
#   Work Item Type IN (User Story, Bug)
#   AND Iteration Path = @CurrentIteration
# Columns: ID, Title, State, Story Points, Assigned To, Remaining Work

# Dashboard widgets (Azure Boards > Dashboards):
# Row 1: Sprint Burndown | Velocity | Team Capacity
# Row 2: Query Results: "P1 Bugs Open" | Code Coverage % | Last Build Status
# Row 3: Deployment Frequency (Release Pipeline Outcomes) | Lead Time Chart

# Share dashboard URL with stakeholders:
# https://dev.azure.com/MyOrg/MyProject/_dashboards/dashboard/{id}
```

---

### Q86. What is the difference between Definition of Ready and Definition of Done?

**Answer:** Definition of Ready (DoR) defines the criteria a work item must meet before it can enter a sprint — ensuring the team has enough information to start work. Criteria: acceptance criteria written, mockups/designs attached, dependencies identified, story points estimated, and no blocking dependencies. Definition of Done (DoD) defines what "complete" means for work that exits the sprint — ensuring quality. Criteria: code reviewed, unit tests passing, acceptance criteria verified, documentation updated, deployed to staging. DoR prevents starting unclear work; DoD prevents shipping incomplete work.

❌ **Violates:**
```yaml
# No DoR or DoD — stories added to sprint without acceptance criteria
# Developers start work without knowing what "done" looks like
# Stories marked "Done" without testing: bugs discovered in production

Sprint backlog:
  - Story: "Improve performance" (no acceptance criteria, no definition)
  - Story: "Fix the login issue" (vague, no steps to reproduce, no criteria)
```

✅ **Satisfies:**
```yaml
# Definition of Ready (before sprint):
# ✅ User story follows "As a [user], I want [goal], so that [reason]" format
# ✅ Acceptance criteria written (at least 3 scenarios in Given/When/Then)
# ✅ UX designs/mockups attached or N/A noted
# ✅ Story estimated (story points assigned by team consensus)
# ✅ Dependencies identified and resolved (or backlog item for each)
# ✅ Team understands enough to start without requiring major clarification

# Definition of Done (before sprint ends):
# ✅ Code reviewed (2 approvals, all comments resolved)
# ✅ All acceptance criteria tested and verified
# ✅ Unit tests written (coverage not decreased)
# ✅ Integration tests pass in CI pipeline
# ✅ Deployed to Dev environment and smoke-tested
# ✅ Performance: no regression (p95 latency not increased by > 10%)
# ✅ No new SonarQube issues introduced
# ✅ Release notes / changelog updated
# ✅ PO acceptance: Product Owner has verified the story
```

---

### Q87. Why do teams use story points instead of hours, and how do you run planning poker?

**Answer:** Story points measure relative complexity, effort, and uncertainty — not hours. A "3-point story" means "roughly as complex as other 3-point stories we've done," relative to the team's experience and codebase. Hours are deceptive: two developers estimate different hours for the same story, but both might agree on "medium complexity." Story points enable velocity tracking (points completed per sprint) for forecasting. Planning poker ensures independent estimates (avoiding anchoring bias), with discussion required when estimates diverge significantly (indicating different understanding of scope).

❌ **Violates:**
```yaml
# Using hours — creates false precision and accountability pressure
Story: "Implement SSO login"
  Alice estimates: 16 hours
  Bob estimates: 8 hours
  Manager says: "Split the difference: 12 hours. Bob, why do you need 8 hours?"
  # Estimates become commitments, developers add padding, velocity becomes meaningless
```

✅ **Satisfies:**
```yaml
# Planning poker with Fibonacci sequence: 1, 2, 3, 5, 8, 13, 21, ?
# Story: "Implement SSO login with Azure AD"
#
# Round 1: everyone reveals simultaneously (prevents anchoring)
#   Alice: 8  (thinks: new library, auth complexity)
#   Bob:   5  (thinks: just adding MSAL package)
#   Carol: 13 (thinks: also need logout, token refresh, test coverage)
#
# Discussion: Carol explains token refresh wasn't obvious to Bob
# Round 2: 8 (consensus — more complex than Bob initially thought)
# Story assigned: 8 SP
#
# Team velocity example:
#   Sprint 1: 38 SP completed
#   Sprint 2: 42 SP completed
#   Sprint 3: 40 SP completed
#   Average velocity: 40 SP/sprint
#   Feature backlog: 160 SP remaining → ~4 sprints to complete

# Azure Boards: Story Points field visible in Backlog
# Velocity widget on dashboard shows actual vs committed SP per sprint
```

---

### Q88. How do area paths and iteration paths organize work for multiple teams?

**Answer:** Area paths represent the organizational/component structure of the work (e.g., `MyProject/Frontend`, `MyProject/Backend/API`, `MyProject/Infrastructure`). Each team configures which area paths they own — their backlog only shows work items in their area. Iteration paths (sprints) define time boxes shared or team-specific. Teams can have their own sprint cadences. This enables multiple teams working on the same Azure DevOps project to have isolated backlogs, sprint boards, and velocity metrics while sharing a common work item store for cross-team dependency queries.

❌ **Violates:**
```yaml
# Single area path — all teams see all work items
# Frontend team's Kanban board shows Backend tasks
# Velocity chart includes work from 3 teams, meaningless
# Sprint planning for Team B accidentally includes Team A items
```

✅ **Satisfies:**
```yaml
# Area path structure:
# MyApp
#   MyApp/Frontend          ← Frontend Team owns this
#   MyApp/Backend
#     MyApp/Backend/API     ← API Team owns this
#     MyApp/Backend/Workers ← Workers Team owns this
#   MyApp/Infrastructure    ← DevOps Team owns this
#   MyApp/Mobile            ← Mobile Team owns this

# Team configuration (Azure DevOps > Project Settings > Teams):
# Frontend Team:
#   - Area paths: MyApp/Frontend
#   - Iterations: MyApp\Sprint 1, MyApp\Sprint 2 (own sprint cadence)
#   - Backlog: shows only Frontend items

# API Team:
#   - Area paths: MyApp/Backend/API
#   - Backlog: shows only API items with separate velocity

# Cross-team dependency:
# Story in MyApp/Frontend can have a link to Story in MyApp/Backend/API
# Dependency query: items tagged #depends-on + linked to cross-team items
```

---

### Q89. How does Azure Boards integrate with GitHub repositories?

**Answer:** Azure Boards can be connected to GitHub repositories, enabling bidirectional traceability: GitHub commits and PRs with `AB#1234` reference appear in the Azure Boards work item timeline, and GitHub PRs can trigger work item state transitions. The integration is configured via Azure DevOps > Project Settings > Boards > GitHub Connections. GitHub Issues can optionally sync with Azure Boards. Teams using GitHub for code and Azure DevOps for project management get the best of both tools — GitHub's developer experience with Azure Boards' portfolio planning.

❌ **Violates:**
```yaml
# Code in GitHub, project management in Azure Boards, no connection
# PR #456 on GitHub has no link to Work Item #789 in Azure Boards
# "What requirements did this PR address?" → manual investigation
# Work item states updated manually by developers days after merge
```

✅ **Satisfies:**
```bash
# Configuration:
# Azure DevOps > Project Settings > GitHub connections
# Connect to GitHub organization > Select repositories

# GitHub commit references Azure Boards work item:
git commit -m "feat: add dark mode toggle AB#1234"
# AB#1234 appears as a link in the work item timeline

# GitHub PR transitions work item:
# PR #456 merged → Work Item #1234 transitions Active → Resolved
# (requires AB# in commit message or PR description)

# GitHub PR title:
# "Feature: Dark mode [AB#1234]"

# In Azure Boards Work Item #1234:
# Development section shows:
# - GitHub commit: abc1234 (feat: add dark mode toggle)
# - GitHub PR: #456 (Feature: Dark mode) — Status: Merged
# - GitHub PR check: CI passing

# Azure Boards > Boards Settings > GitHub Integration:
# Auto-transition on PR merge: Active → Resolved
# Auto-transition on PR closed without merge: Active (revert)
```

---

### Q90. How do Azure Boards Analytics, velocity charts, and Power BI reporting work?

**Answer:** Azure Boards Analytics is a built-in reporting service that provides pre-built widgets (Velocity, Sprint Burndown, Cumulative Flow Diagram, Lead Time, Cycle Time) and an OData endpoint for custom queries. Velocity charts show story points committed vs completed per sprint, revealing team predictability. The Cumulative Flow Diagram visualizes work item distribution across board columns over time, identifying bottlenecks (when a column grows thick, work is piling up). Power BI Desktop connects to the Analytics OData endpoint for custom reports combining Boards, Pipelines, and Test data.

❌ **Violates:**
```yaml
# No analytics — sprint reviews consist of manually counting work items
# "How many story points did we complete last quarter?" → export to Excel
# Decisions made on gut feeling rather than data
# Cannot identify team bottlenecks or predict delivery dates
```

✅ **Satisfies:**
```yaml
# Azure Boards built-in analytics:
# 1. Velocity widget:
#    - Bars per sprint: Planned SP (blue) vs Completed SP (green)
#    - 6-sprint average: 42 SP/sprint
#    - Trend: velocity improving or declining?

# 2. Sprint Burndown:
#    - X axis: sprint days, Y axis: remaining work (hours or SP)
#    - Ideal line vs actual
#    - Early warning: actual line above ideal = sprint at risk

# 3. Cumulative Flow Diagram (CFD):
#    - Shows work items in each state over time
#    - Thin bands = fast flow, thick band = bottleneck
#    - Bottleneck in "Code Review" column → need more reviewers

# 4. Lead Time / Cycle Time distribution:
#    - Lead Time: from creation to done (customer perspective)
#    - Cycle Time: from active to done (team throughput)
#    - Outliers identify items that got stuck

# Power BI OData query:
# https://analytics.dev.azure.com/{org}/{project}/_odata/v3.0-preview/WorkItemSnapshot
# ?$apply=filter(WorkItemType eq 'User Story' and StateCategory eq 'Completed')
# /groupby((CompletedDateSK, IterationPath), aggregate(StoryPoints with sum as Points))

# Dashboard with stakeholder-friendly view:
# - Release progress by Feature (% complete)
# - P1 bug count trend (decreasing = improving quality)
# - Deployment frequency (deploys per week)
# - Mean time to restore (MTTR from incidents)
```

> 📚 Reference: [Azure Boards Documentation](https://docs.microsoft.com/en-us/azure/devops/boards/)
> 📚 Medium: [Data-Driven Agile with Azure Boards Analytics and Power BI](https://medium.com/data-driven-agile-azure-boards)

---

## Section 10 — GCP Cloud Storage Integration

### Q91. What is GCP Cloud Storage and how does it compare to Azure Blob Storage and AWS S3?

**Answer:** GCP Cloud Storage (GCS) is Google's globally distributed object storage service with four storage classes: Standard (hot data, frequent access), Nearline (monthly access, lower cost), Coldline (quarterly access), and Archive (yearly access, cheapest, highest retrieval cost). Objects are stored in Buckets (equivalent to Azure Blob containers / S3 buckets). GCS uses flat object namespace with `/` in names simulating folders. Compared to Azure Blob: GCS uses IAM with Google identities vs Azure RBAC with Azure AD identities; both support lifecycle rules, versioning, and CDN integration. S3 and GCS have near-identical feature sets; GCS pricing is slightly lower for egress within Google Cloud.

❌ **Violates:**
```csharp
// Treating GCS bucket like a filesystem with real directories
var storage = StorageClient.Create();
// Creating "folder" objects is a GCS anti-pattern
await storage.UploadObjectAsync("my-bucket", "folder/", "application/x-directory", Stream.Null);
// GCS has no real directories — the "/" in object names is just convention
```

✅ **Satisfies:**
```csharp
// GCS objects with "/" in names — simulated folder hierarchy
// "reports/2024/12/sales-report.pdf" is one flat object key
// Storage classes per bucket:
// Standard:  gs://myapp-hot-data/       — user uploads, frequent reads
// Nearline:  gs://myapp-monthly-logs/   — log archives, monthly access
// Coldline:  gs://myapp-quarterly-backup/ — database backups
// Archive:   gs://myapp-compliance/      — regulatory records, 7-year retention

// Comparison cheat sheet:
// Feature          | GCS              | Azure Blob        | S3
// Auth             | IAM (Google)     | RBAC (Azure AD)   | IAM (AWS)
// Consistency      | Strong           | Strong            | Strong
// Min storage time | None/30/90/365d  | None/30/90/180d   | None/30/90/180d
// URL format       | gs://bucket/obj  | account.blob.core | s3://bucket/key
```

---

### Q92. How do you authenticate a .NET application to GCP Cloud Storage?

**Answer:** Three authentication methods for .NET GCP: Service Account JSON Key (download key file, set `GOOGLE_APPLICATION_CREDENTIALS` env var — portable but requires secret management), Application Default Credentials / ADC (uses environment-configured credentials: Workload Identity on GKE, `gcloud auth application-default login` locally, service account on Compute Engine — preferred for GCP-hosted apps), and Workload Identity Federation (federate Azure DevOps or any OIDC provider to GCP — no JSON key, zero-credentials approach). The `Google.Cloud.Storage.V1` NuGet package's `StorageClient.Create()` auto-discovers credentials via ADC.

❌ **Violates:**
```csharp
// Service account JSON key hardcoded in code or checked into Git
var credential = GoogleCredential.FromJson(@"{
    ""type"": ""service_account"",
    ""client_email"": ""myapp@myproject.iam.gserviceaccount.com"",
    ""private_key"": ""-----BEGIN RSA PRIVATE KEY-----\nMIIEp..."",
    // Private key in source code — catastrophic security failure
}");
```

✅ **Satisfies:**
```csharp
// Option 1: Application Default Credentials (recommended for GCP-hosted)
// Credentials auto-discovered from environment:
// - GKE: Workload Identity
// - Compute Engine: attached service account
// - Cloud Run: attached service account
// - Local dev: gcloud auth application-default login
using Google.Cloud.Storage.V1;

public class GcsService
{
    private readonly StorageClient _storage;

    public GcsService()
    {
        // ADC: no credentials in code
        _storage = StorageClient.Create();
    }
}

// Option 2: Service account key from environment variable (not in code)
// Environment: GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/gcs-key.json
var storage = StorageClient.Create();   // same call — ADC reads the env var

// Option 3: Explicit credential from Key Vault / Secret Manager
var json = await secretManagerClient.AccessSecretVersionAsync(secretVersionName);
var credential = GoogleCredential.FromJson(json.Payload.Data.ToStringUtf8());
var storage = StorageClient.Create(credential);

// Program.cs registration:
builder.Services.AddSingleton(_ => StorageClient.Create());
builder.Services.AddScoped<IGcsService, GcsService>();
```

---

### Q93. How do you upload files to GCP Cloud Storage from a .NET application?

**Answer:** `StorageClient.UploadObjectAsync()` uploads a stream to GCS with the specified bucket name, object name (key), and content type. For files < 5 MB, the simple upload works well. For large files (> 5 MB), resumable uploads handle network interruptions automatically and are default for streams > threshold. Custom metadata (key-value pairs) can be attached to objects at upload time. Setting `CacheControl`, `ContentEncoding`, and `ContentDisposition` headers controls browser and CDN behavior for served objects.

❌ **Violates:**
```csharp
// Loading entire file into memory before uploading — OOM risk for large files
byte[] fileBytes = File.ReadAllBytes("huge-video.mp4");  // 2 GB file → OOM
MemoryStream ms = new MemoryStream(fileBytes);
await storage.UploadObjectAsync("my-bucket", "video.mp4", "video/mp4", ms);
```

✅ **Satisfies:**
```csharp
using Google.Cloud.Storage.V1;
using Google.Apis.Storage.v1.Data;

public class GcsUploadService
{
    private readonly StorageClient _storage;

    public async Task<string> UploadFileAsync(
        string bucketName,
        string objectName,
        Stream fileStream,
        string contentType,
        CancellationToken cancellationToken = default)
    {
        var uploadOptions = new UploadObjectOptions
        {
            // Resumable upload for reliability (default for streams > 5MB)
            ChunkSize = UploadObjectOptions.MinimumChunkSize * 4  // 1MB chunks
        };

        var objectMetadata = new Google.Apis.Storage.v1.Data.Object
        {
            Bucket = bucketName,
            Name = objectName,
            ContentType = contentType,
            CacheControl = "public, max-age=3600",
            Metadata = new Dictionary<string, string>
            {
                { "uploaded-by", "myapp-api" },
                { "upload-date", DateTime.UtcNow.ToString("O") }
            }
        };

        // Stream uploaded in chunks — memory efficient even for large files
        var result = await _storage.UploadObjectAsync(
            objectMetadata,
            fileStream,
            uploadOptions,
            cancellationToken);

        return $"gs://{bucketName}/{objectName}";
    }

    // Upload from local file path
    public async Task UploadLocalFileAsync(string bucketName, string objectName, string localPath)
    {
        using var fileStream = File.OpenRead(localPath);
        var contentType = GetContentType(localPath);
        await _storage.UploadObjectAsync(bucketName, objectName, contentType, fileStream);
    }

    private static string GetContentType(string path) =>
        Path.GetExtension(path).ToLower() switch
        {
            ".jpg" or ".jpeg" => "image/jpeg",
            ".png"  => "image/png",
            ".pdf"  => "application/pdf",
            ".zip"  => "application/zip",
            _       => "application/octet-stream"
        };
}
```

---

### Q94. How do you download objects from GCP Cloud Storage, including signed URLs for direct client access?

**Answer:** `StorageClient.DownloadObjectAsync()` downloads an object to a stream — suitable for server-side downloads where the server retrieves the file and processes or streams it to the client. Signed URLs (V4) grant time-limited direct access to GCS objects without requiring Google credentials, enabling clients to download directly from GCS without routing through your server. The `UrlSigner` class generates signed URLs for GET (download) or PUT (upload) operations with configurable expiry duration.

❌ **Violates:**
```csharp
// Generating signed URLs with raw service account key in code
var signer = UrlSigner.FromServiceAccountCredential(
    new ServiceAccountCredential(new ServiceAccountCredential.Initializer("email")
    {
        Key = RSA.Create() // hardcoded private key — security risk
    }));
// Also: V2 signed URLs (deprecated) have weaker security than V4
```

✅ **Satisfies:**
```csharp
using Google.Cloud.Storage.V1;

public class GcsDownloadService
{
    private readonly StorageClient _storage;
    private readonly UrlSigner _urlSigner;

    public GcsDownloadService(StorageClient storage)
    {
        _storage = storage;
        // UrlSigner uses ADC automatically — no hardcoded keys
        _urlSigner = UrlSigner.FromCredential(GoogleCredential.GetApplicationDefault());
    }

    // Server-side download: download to HTTP response stream
    public async Task StreamToResponseAsync(
        string bucketName,
        string objectName,
        HttpResponse response,
        CancellationToken ct)
    {
        var obj = await _storage.GetObjectAsync(bucketName, objectName);
        response.ContentType = obj.ContentType;
        response.Headers["Content-Disposition"] = $"attachment; filename=\"{Path.GetFileName(objectName)}\"";

        // Stream directly to response body — no memory buffering
        await _storage.DownloadObjectAsync(bucketName, objectName, response.Body, cancellationToken: ct);
    }

    // Generate V4 signed URL for direct client download (no server proxy)
    public async Task<string> GenerateDownloadSignedUrlAsync(
        string bucketName,
        string objectName,
        TimeSpan expiry)
    {
        var signedUrl = await _urlSigner.SignAsync(
            bucketName,
            objectName,
            expiry,
            HttpMethod.Get,
            signingVersion: UrlSigner.SigningVersion.V4);

        return signedUrl;
        // URL valid for 'expiry' duration only
        // Client downloads directly from GCS: no server bandwidth cost
    }

    // Generate V4 signed URL for client-side upload (PUT)
    public async Task<string> GenerateUploadSignedUrlAsync(
        string bucketName,
        string objectName,
        string contentType,
        TimeSpan expiry)
    {
        var headers = new Dictionary<string, IEnumerable<string>>
        {
            { "Content-Type", new[] { contentType } }
        };

        return await _urlSigner.SignAsync(
            bucketName,
            objectName,
            expiry,
            HttpMethod.Put,
            headers,
            signingVersion: UrlSigner.SigningVersion.V4);
    }
}
```

---

### Q95. How does IAM work for GCP Cloud Storage buckets?

**Answer:** GCS IAM uses Google Cloud roles granted on buckets or at the project level. Key predefined roles: `roles/storage.objectViewer` (download objects), `roles/storage.objectCreator` (upload new objects, cannot overwrite), `roles/storage.objectAdmin` (full object CRUD), and `roles/storage.admin` (full bucket + object control). Uniform bucket-level access (recommended) disables per-object ACLs and enforces IAM consistently across all objects. Fine-grained ACLs (legacy) allow per-object permissions but are harder to audit. Service accounts represent application identities; human users use their Google accounts.

❌ **Violates:**
```yaml
# Making bucket publicly accessible — any internet user can download objects
# gsutil iam ch allUsers:objectViewer gs://my-private-data-bucket
# All user data, backups, and internal reports exposed to the internet
```

✅ **Satisfies:**
```yaml
# IAM policy for GCS bucket (set via gcloud CLI or Terraform):
# Principle of least privilege:

# Application service account: objectAdmin on specific bucket only
# gcloud storage buckets add-iam-policy-binding gs://myapp-uploads \
#   --member="serviceAccount:myapp-api@myproject.iam.gserviceaccount.com" \
#   --role="roles/storage.objectAdmin"

# CI/CD service account: objectCreator (can publish artifacts, cannot delete)
# gcloud storage buckets add-iam-policy-binding gs://myapp-artifacts \
#   --member="serviceAccount:ci-pipeline@myproject.iam.gserviceaccount.com" \
#   --role="roles/storage.objectCreator"

# Read-only for reporting service:
# gcloud storage buckets add-iam-policy-binding gs://myapp-reports \
#   --member="serviceAccount:reporting@myproject.iam.gserviceaccount.com" \
#   --role="roles/storage.objectViewer"

# Enable uniform bucket-level access (disable legacy ACLs):
# gcloud storage buckets update gs://myapp-uploads --uniform-bucket-level-access
```

```csharp
// Checking permissions programmatically (for admin tools)
using Google.Cloud.Storage.V1;

var storage = StorageClient.Create();
var policy = await storage.GetBucketIamPolicyAsync("my-bucket");
foreach (var binding in policy.Bindings)
{
    Console.WriteLine($"Role: {binding.Role}");
    foreach (var member in binding.Members)
        Console.WriteLine($"  Member: {member}");
}
```

---

### Q96. How do you generate and use signed URLs in .NET for secure, time-limited GCS access?

**Answer:** Signed URLs are pre-authenticated URLs that grant temporary access to specific GCS objects without requiring the requester to have Google credentials. They embed the service account's digital signature, bucket, object name, HTTP method, and expiry time. V4 signed URLs use HMAC-SHA256 and are valid up to 7 days. Common use cases: allowing browsers to download private files, allowing mobile apps to upload directly to GCS without routing through the API server, and sharing reports with external stakeholders without giving them Google Cloud access.

❌ **Violates:**
```csharp
// Generating signed URLs with a 30-day expiry — too long, security risk
var url = await urlSigner.SignAsync(bucket, obj, TimeSpan.FromDays(30), HttpMethod.Get);
// If URL is leaked/shared, attacker has 30-day access to the object
// Also: no Content-Type restriction on PUT — anyone can upload anything
```

✅ **Satisfies:**
```csharp
[ApiController]
[Route("api/files")]
public class FilesController : ControllerBase
{
    private readonly UrlSigner _urlSigner;
    private readonly string _bucket = "myapp-private-files";

    // GET: generate a short-lived download URL
    [HttpGet("{fileId}/download-url")]
    [Authorize]
    public async Task<IActionResult> GetDownloadUrl(Guid fileId)
    {
        // Resolve object name from fileId (database lookup)
        var objectName = $"user-uploads/{fileId}.pdf";

        // 15-minute download URL — short-lived for security
        var url = await _urlSigner.SignAsync(
            _bucket,
            objectName,
            TimeSpan.FromMinutes(15),
            HttpMethod.Get,
            signingVersion: UrlSigner.SigningVersion.V4);

        return Ok(new { downloadUrl = url, expiresInSeconds = 900 });
    }

    // POST: generate a short-lived upload URL (client uploads directly to GCS)
    [HttpPost("upload-url")]
    [Authorize]
    public async Task<IActionResult> GetUploadUrl([FromBody] UploadRequest request)
    {
        var fileId = Guid.NewGuid();
        var objectName = $"user-uploads/{fileId}{Path.GetExtension(request.FileName)}";

        // Restrict to specific Content-Type (prevent malicious uploads)
        var requestHeaders = new Dictionary<string, IEnumerable<string>>
        {
            { "Content-Type", new[] { request.ContentType } },
            { "x-goog-meta-uploaded-by", new[] { User.Identity!.Name! } }
        };

        var uploadUrl = await _urlSigner.SignAsync(
            _bucket,
            objectName,
            TimeSpan.FromMinutes(10),   // 10-minute window to complete upload
            HttpMethod.Put,
            requestHeaders,
            signingVersion: UrlSigner.SigningVersion.V4);

        return Ok(new { uploadUrl, objectName, fileId });
    }
}
```

---

### Q97. How do GCS lifecycle rules work and how do you configure them in .NET?

**Answer:** Lifecycle rules automatically perform actions on GCS objects based on conditions: age (days since creation), storage class, number of versions, creation date, and whether the object is a live or non-current version. Actions: delete object, change storage class (e.g., Standard → Nearline → Coldline → Archive), or delete non-current versions after a number of days. Lifecycle policies reduce storage costs by automatically moving old data to cheaper storage classes and deleting data that exceeds retention requirements.

❌ **Violates:**
```yaml
# No lifecycle rules — storage grows indefinitely
# Log bucket: 5 TB after 1 year, $100/month storage cost
# Old test artifacts never deleted, CI pipeline artifacts accumulate
# Compliance violation: PII data retained longer than required
```

✅ **Satisfies:**
```csharp
using Google.Cloud.Storage.V1;
using Google.Apis.Storage.v1.Data;

public async Task SetBucketLifecyclePolicyAsync(string bucketName)
{
    var storage = StorageClient.Create();

    var lifecycle = new Bucket.LifecycleData
    {
        Rule = new List<Bucket.LifecycleData.RuleData>
        {
            // Rule 1: Move to Nearline after 30 days (costs 60% less than Standard)
            new()
            {
                Action = new Bucket.LifecycleData.RuleData.ActionData
                    { Type = "SetStorageClass", StorageClass = "NEARLINE" },
                Condition = new Bucket.LifecycleData.RuleData.ConditionData
                    { Age = 30 }
            },
            // Rule 2: Move to Coldline after 90 days
            new()
            {
                Action = new Bucket.LifecycleData.RuleData.ActionData
                    { Type = "SetStorageClass", StorageClass = "COLDLINE" },
                Condition = new Bucket.LifecycleData.RuleData.ConditionData
                    { Age = 90 }
            },
            // Rule 3: Delete after 365 days (compliance: 1-year retention)
            new()
            {
                Action = new Bucket.LifecycleData.RuleData.ActionData { Type = "Delete" },
                Condition = new Bucket.LifecycleData.RuleData.ConditionData { Age = 365 }
            },
            // Rule 4: Delete old versions (keep only 3 non-current versions)
            new()
            {
                Action = new Bucket.LifecycleData.RuleData.ActionData { Type = "Delete" },
                Condition = new Bucket.LifecycleData.RuleData.ConditionData
                {
                    IsLive = false,
                    NumNewerVersions = 3   // delete old versions when > 3 newer exist
                }
            }
        }
    };

    var bucket = await storage.GetBucketAsync(bucketName);
    bucket.Lifecycle = lifecycle;
    await storage.UpdateBucketAsync(bucket);
}
```

---

### Q98. How do you use GCP Cloud Storage in Azure DevOps CI/CD pipelines?

**Answer:** GCS integrates into Azure Pipelines for: uploading build artifacts to GCS (replacing or complementing Azure Artifacts), storing Terraform remote state in a GCS bucket, caching build dependencies, and syncing deployment packages to globally distributed storage. Authentication in pipeline uses a GCP service account JSON key stored as a Secure File or Key Vault secret. `gsutil` (Google Cloud SDK) is the CLI tool, or the `Google.Cloud.Storage.V1` .NET SDK can be called from a script task.

❌ **Violates:**
```yaml
# Hardcoding GCP service account key in pipeline YAML
steps:
  - script: |
      echo '{"type":"service_account","private_key":"-----BEGIN RSA..."}' > /tmp/key.json
      export GOOGLE_APPLICATION_CREDENTIALS=/tmp/key.json
      gsutil cp artifact.zip gs://my-bucket/
      # Service account key in YAML, in pipeline logs, in Git history
```

✅ **Satisfies:**
```yaml
# GCP service account key stored as Azure DevOps Secure File
steps:
  - task: DownloadSecureFile@1
    name: gcpKey
    displayName: 'Download GCP Service Account Key'
    inputs:
      secureFile: 'gcp-ci-service-account.json'

  - task: GoogleCloudSdkTool@1
    displayName: 'Install Google Cloud SDK'

  - bash: |
      # Authenticate with key from Secure File
      gcloud auth activate-service-account --key-file=$(gcpKey.secureFilePath)
      gcloud config set project my-gcp-project

      # Upload build artifact to GCS
      gsutil -m cp -r $(Build.ArtifactStagingDirectory)/* gs://myapp-artifacts/$(Build.BuildNumber)/

      # Verify upload
      gsutil ls gs://myapp-artifacts/$(Build.BuildNumber)/
    displayName: 'Upload Artifacts to GCS'

  # Terraform with GCS remote state
  - bash: |
      gcloud auth activate-service-account --key-file=$(gcpKey.secureFilePath)
      terraform init \
        -backend-config="bucket=myapp-terraform-state" \
        -backend-config="prefix=prod/myapp"
      terraform plan -out=tfplan
    displayName: 'Terraform Plan (GCS backend)'
    workingDirectory: terraform/
    env:
      GOOGLE_APPLICATION_CREDENTIALS: $(gcpKey.secureFilePath)
```

---

### Q99. How do you stream large files efficiently between GCS and an ASP.NET Core API?

**Answer:** For large file downloads from GCS to HTTP clients, avoid loading the entire file into memory — instead pipe the GCS download stream directly to the HTTP response body stream. For large uploads from clients to GCS, read the request body stream and pipe it to `UploadObjectAsync`. Resumable uploads handle the upload atomically with automatic retry for network failures. Setting appropriate `Content-Length` and streaming without buffering keeps memory usage constant regardless of file size.

❌ **Violates:**
```csharp
// Loading entire GCS object into memory before sending to client
[HttpGet("download/{objectName}")]
public async Task<IActionResult> Download(string objectName)
{
    using var ms = new MemoryStream();
    await _storage.DownloadObjectAsync("my-bucket", objectName, ms);
    ms.Position = 0;
    var bytes = ms.ToArray();   // 2 GB file → 2 GB RAM per request
    return File(bytes, "application/octet-stream", objectName);
}
```

✅ **Satisfies:**
```csharp
[ApiController]
[Route("api/storage")]
public class StorageController : ControllerBase
{
    private readonly StorageClient _storage;
    private const string BucketName = "myapp-large-files";

    // Stream GCS → HTTP response (constant memory usage regardless of file size)
    [HttpGet("download/{**objectName}")]
    [Authorize]
    public async Task StreamDownload(string objectName, CancellationToken ct)
    {
        // Get metadata first (for Content-Type and Content-Length)
        var obj = await _storage.GetObjectAsync(BucketName, objectName, cancellationToken: ct);

        Response.ContentType = obj.ContentType ?? "application/octet-stream";
        Response.Headers["Content-Disposition"] = $"attachment; filename=\"{Path.GetFileName(objectName)}\"";
        if (obj.Size.HasValue)
            Response.ContentLength = (long)obj.Size.Value;

        // Stream directly from GCS to response body — O(chunk) memory usage
        await _storage.DownloadObjectAsync(
            BucketName,
            objectName,
            Response.Body,        // HttpResponse.Body is the wire directly
            cancellationToken: ct);
    }

    // Stream HTTP upload → GCS (client uploads large file to API → GCS)
    [HttpPost("upload/{**objectName}")]
    [Authorize]
    [DisableRequestSizeLimit]         // allow large files
    [RequestFormLimits(MultipartBodyLengthLimit = long.MaxValue)]
    public async Task<IActionResult> StreamUpload(string objectName, CancellationToken ct)
    {
        var contentType = Request.ContentType ?? "application/octet-stream";

        // Request.Body is streamed — not buffered in memory
        var gcsObject = await _storage.UploadObjectAsync(
            BucketName,
            objectName,
            contentType,
            Request.Body,          // pipe request body directly to GCS
            cancellationToken: ct);

        return Ok(new
        {
            objectName = gcsObject.Name,
            size = gcsObject.Size,
            gcsUri = $"gs://{BucketName}/{objectName}"
        });
    }
}
```

---

### Q100. What are the key differences between GCP Cloud Storage and Azure Blob Storage, and what should you consider when migrating?

**Answer:** GCP Cloud Storage and Azure Blob Storage are functionally equivalent object stores with differences in auth model (GCS uses Google IAM/service accounts vs Azure RBAC/managed identities), SDK design (GCS uses `StorageClient` with `UploadObjectAsync` vs Azure uses `BlobServiceClient` → `BlobContainerClient` → `BlobClient`), URL format (GCS: `https://storage.googleapis.com/bucket/object` vs Azure: `https://account.blob.core.windows.net/container/blob`), and SAS/signed URL mechanism (GCS V4 signed URLs vs Azure SAS tokens with different parameters). Migration uses Storage Transfer Service (GCS → GCS or S3 → GCS) or `gsutil rsync` / `azcopy` for cross-cloud transfer.

❌ **Violates:**
```csharp
// Direct copy-paste of Azure Blob code assuming it works for GCS
// Azure pattern:
var containerClient = new BlobContainerClient(connectionString, "my-container");
var blobClient = containerClient.GetBlobClient("my-blob.pdf");
await blobClient.UploadAsync(stream);

// Assuming GCS works the same way — incorrect, different SDK entirely
// Google.Cloud.Storage.V1 has completely different API surface
```

✅ **Satisfies:**
```csharp
// Abstraction layer — switch storage providers without changing business logic
public interface IObjectStorageService
{
    Task UploadAsync(string container, string objectName, Stream data, string contentType, CancellationToken ct = default);
    Task DownloadAsync(string container, string objectName, Stream destination, CancellationToken ct = default);
    Task<string> GenerateSignedDownloadUrlAsync(string container, string objectName, TimeSpan expiry);
    Task DeleteAsync(string container, string objectName, CancellationToken ct = default);
}

// Azure Blob implementation
public class AzureBlobStorageService : IObjectStorageService
{
    private readonly BlobServiceClient _client;

    public async Task UploadAsync(string container, string objectName, Stream data, string contentType, CancellationToken ct)
    {
        var containerClient = _client.GetBlobContainerClient(container);
        var blobClient = containerClient.GetBlobClient(objectName);
        await blobClient.UploadAsync(data, new BlobUploadOptions { HttpHeaders = new BlobHttpHeaders { ContentType = contentType } }, ct);
    }

    public async Task<string> GenerateSignedDownloadUrlAsync(string container, string objectName, TimeSpan expiry)
    {
        var blobClient = _client.GetBlobContainerClient(container).GetBlobClient(objectName);
        var sasUri = blobClient.GenerateSasUri(BlobSasPermissions.Read, DateTimeOffset.UtcNow.Add(expiry));
        return sasUri.ToString();
    }

    public async Task DownloadAsync(string container, string objectName, Stream destination, CancellationToken ct)
    {
        var blobClient = _client.GetBlobContainerClient(container).GetBlobClient(objectName);
        await blobClient.DownloadToAsync(destination, ct);
    }

    public async Task DeleteAsync(string container, string objectName, CancellationToken ct)
    {
        var blobClient = _client.GetBlobContainerClient(container).GetBlobClient(objectName);
        await blobClient.DeleteIfExistsAsync(cancellationToken: ct);
    }
}

// GCS implementation — same interface, different SDK
public class GcsStorageService : IObjectStorageService
{
    private readonly StorageClient _storage;
    private readonly UrlSigner _signer;

    public async Task UploadAsync(string container, string objectName, Stream data, string contentType, CancellationToken ct)
        => await _storage.UploadObjectAsync(container, objectName, contentType, data, cancellationToken: ct);

    public async Task<string> GenerateSignedDownloadUrlAsync(string container, string objectName, TimeSpan expiry)
        => await _signer.SignAsync(container, objectName, expiry, HttpMethod.Get, signingVersion: UrlSigner.SigningVersion.V4);

    public async Task DownloadAsync(string container, string objectName, Stream destination, CancellationToken ct)
        => await _storage.DownloadObjectAsync(container, objectName, destination, cancellationToken: ct);

    public async Task DeleteAsync(string container, string objectName, CancellationToken ct)
        => await _storage.DeleteObjectAsync(container, objectName, cancellationToken: ct);
}

// DI registration — switch via configuration
// builder.Services.AddScoped<IObjectStorageService, AzureBlobStorageService>();
// builder.Services.AddScoped<IObjectStorageService, GcsStorageService>();
```

> 📚 Reference: [Google Cloud Storage .NET Client Library](https://cloud.google.com/storage/docs/reference/libraries#client-libraries-install-csharp)
> 📚 Medium: [GCP Cloud Storage in .NET — Authentication, Upload, Download, and Signed URLs](https://medium.com/gcp-cloud-storage-dotnet)

---

## Summary

This guide covered 100 interview questions across 10 sections:

| Section | Topic | Questions |
|---------|-------|-----------|
| 1 | Azure DevOps Overview & Repos | Q1–Q10 |
| 2 | CI Pipelines | Q11–Q20 |
| 3 | CD & Multi-Stage Pipelines | Q21–Q30 |
| 4 | YAML Pipeline Deep Dive | Q31–Q40 |
| 5 | Artifacts & Package Management | Q41–Q50 |
| 6 | Pipeline Security & Secrets | Q51–Q60 |
| 7 | Testing in Pipelines | Q61–Q70 |
| 8 | Deployment Strategies | Q71–Q80 |
| 9 | Azure Boards & Agile | Q81–Q90 |
| 10 | GCP Cloud Storage Integration | Q91–Q100 |

Key themes throughout:
- **Security first**: OIDC/managed identity over secrets, protected resources, secret masking
- **Pipeline as Code**: YAML in Git, templates for DRY, peer-reviewed pipeline changes
- **Quality gates**: SonarQube, coverage thresholds, test results published to every run
- **Zero-downtime**: slot swaps, blue-green, canary, feature flags for safe deployments
- **Traceability**: AB# linking from commits to work items to deployments to monitoring

---
