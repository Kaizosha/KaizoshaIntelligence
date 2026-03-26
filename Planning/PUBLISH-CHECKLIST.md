# Publish Checklist

This checklist is for the actual release action after the code is ready.

## Verified Locally

- [x] `swift build`
- [x] `swift test`
- [x] DocC generation for `KaizoshaIntelligence`
- [x] Release metadata files exist
- [x] CI workflow exists
- [x] V1 checklist is complete
- [x] Release notes drafted
- [x] Commit message drafted
- [x] Tag message drafted

## Optional Before Publishing

- [ ] Run live provider smoke tests with real credentials
- [ ] Review generated DocC archive locally
- [ ] Final README wording review

## Publish Steps

- [ ] Commit the release contents
- [ ] Create tag `0.1.0`
- [ ] Push the branch and tag
- [ ] Create the GitHub release using `RELEASE_NOTES_0.1.0.md`
