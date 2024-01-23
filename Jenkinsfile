@Library('jenkins-library@feature/DOPS-2956') _

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
    appTests: false,
    jobParams: jobParams,
    label: "mac-sora",
    appPushNoti: true,
    dojoProductType: 'sora-mobile'
)

pipeline.runPipeline('sora')
