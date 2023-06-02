@Library('jenkins-library@feature/DOPS-2461/fix_sonar') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
  booleanParam(defaultValue: false, description: 'allow quality gate', name: 'sonarQualityGate'),
]

def pipline = new org.ios.AppPipeline(
    steps: this,
    sonar: true,
    sonarProjectName: 'sora-passport-ios',
    sonarProjectKey: 'jp.co.soramitsu:sora-passport-ios',
    // appTests: false,
    sonarTestsDirs: './SoraPassportTests,./SoraPassportIntegrationTests,./SoraPassportUITests',
    jobParams: jobParams,
    label: "macos-ios-1-2",
    appPushNoti: true
)
pipline.runPipeline('sora')
