// Pipeline B (scaffold)
// Parameters: REPLICAS + IMAGE_TAG (scale and update image)
pipeline {
  agent any
  parameters {
    string(name: 'REPLICAS', defaultValue: '1', description: 'Target replica count')
    string(name: 'IMAGE_TAG', defaultValue: 'local', description: 'Image tag to deploy')
  }
  stages {
    stage('Apply scale + image tag') {
      steps { echo "Scale=${params.REPLICAS} ImageTag=${params.IMAGE_TAG}" }
    }
  }
}
