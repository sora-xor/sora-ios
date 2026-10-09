@Library('jenkins-library@65079bbe356bca4a3d5a1964e360498735afa1f0') _

// Legacy Soramitsu Jenkins pipeline (build, unit tests, Sonar). Pull-request
// checks run in .github/workflows/ios_ci.yml. Use the same Xcode on this agent
// as in ios_ci.yml (set DEVELOPER_DIR on the mac-sora agent); see
// docs/release-3.9.0/RELEASE-CHECKLIST.md.

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
  booleanParam(defaultValue: false, description: 'allow quality gate', name: 'sonarQualityGate'),
]

def pipeline = new org.ios.AppPipeline(
    steps: this,
    sonar: true,
    sonarProjectName: 'sora-ios',
    sonarProjectKey: 'sora:sora-ios',
    appTests: true,
    jobParams: jobParams,
    label: "mac-sora",
    appPushNoti: true,
    dojoProductType: 'sora-mobile'
)

pipeline.runPipeline('sora')
