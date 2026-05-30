# GhosttyConfigurator — Claude project instructions

## Workflow rule (apply after every working pass)

After completing a pass on the gap-fix plan (or any feature work), do **all of the following** before reporting the pass as complete:

1. **Bump the version** in `Configs/Common.xcconfig`:
   - Patch bump `MARKETING_VERSION` (e.g. `0.1.0` → `0.1.1`) for each pass
   - Increment `CURRENT_PROJECT_VERSION` (build number) by 1
2. **Build and verify** the change compiles (`xcodebuild ... CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=""`)
3. **Copy the freshly-built `.app` to the project root** so the user can launch it from Finder without digging into DerivedData:
   ```
   rm -rf ./GhosttyConfigurator.app
   cp -R ~/Library/Developer/Xcode/DerivedData/GhosttyConfigurator-*/Build/Products/Debug/GhosttyConfigurator.app ./
   ```
   The copied `.app` is gitignored — see `.gitignore`.
4. **Make a git commit** covering the pass:
   - Conventional, terse commit message
   - Include version bump in the same commit
5. **Mention** the new version and commit SHA in the response to the user

This rule is durable across conversations — do not require re-confirmation.

## Build / run notes

- Project uses XcodeGen — `project.yml` is the source of truth; the `.xcodeproj` is git-ignored
- Two `.app` outputs exist on disk:
  - `~/Library/Developer/Xcode/DerivedData/GhosttyConfigurator-*/Build/Products/Debug/GhosttyConfigurator.app` (fresh)
  - `~/Projects/GhosttyConfigurator/build/Build/Products/Debug/GhosttyConfigurator.app` (stale, from an older Xcode run-destination setting)
- LaunchServices may resolve `open -b <bundle-id>` to either. Always launch the fresh build by **explicit path** when verifying changes:
  `open -n ~/Library/Developer/Xcode/DerivedData/GhosttyConfigurator-*/Build/Products/Debug/GhosttyConfigurator.app`

## Plan source

- `docs/00-PLAN.md` is the authoritative spec
- `.claude/gap-fix-plan.md` enumerates the delta between spec and current implementation, ordered by leverage
- Work items execute in the order listed in "Suggested execution order" at the bottom of the gap plan
