@Library('jenkins-library') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
  booleanParam(defaultValue: false, description: 'allow quality gate', name: 'sonarQualityGate'),
]

def pipeline = new org.ios.AppPipeline(
    steps: this,
    sonar: false,
    sonarProjectName: 'sora-ios',
    sonarProjectKey: 'sora:sora-ios',
    appTests: false,
    sonarTestsDirs: './SoraPassportTests,./SoraPassportIntegrationTests,./SoraPassportUITests',
    jobParams: jobParams,
    label: "mac-sora",
    //label: "macos-ios-1-2",
    appPushNoti: true,
    dojoProductType: 'sora'
)

pipeline.runPipeline('sora')
