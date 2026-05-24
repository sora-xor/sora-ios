@Library('jenkins-library') _

// Job properties
def jobParams = [
  booleanParam(defaultValue: false, description: 'push to the dev profile', name: 'prDeployment'),
  booleanParam(defaultValue: false, description: 'allow quality gate', name: 'sonarQualityGate'),
]

def pipeline = new org.ios.AppPipeline(
    steps: this,
    spmEnabled: true,
    sonar: true,
    sonarProjectName: 'shared-features-spm',
    sonarProjectKey: 'sora:shared-features-spm',
    lintEnable: true,
    linterFile: 'tools/swiftformat/swiftformat',
    lintDir: 'Sources',
    disableUpdatePods: true,
    disableInstallPods: true,
    jobParams: jobParams,
    dojoProductType: "sora-mobile",
    label: "mac-mcst-common-2"
)

pipeline.runPipeline('shared-features-spm')