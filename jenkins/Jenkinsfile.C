// Pipeline C (scaffold)
// Parameterized file content injection into pod filesystem
pipeline {
  agent any
  parameters {
    text(name: 'FILE_CONTENT', defaultValue: 'hello from jenkins', description: 'Content to inject')
  }
  stages {
    stage('Inject file content') {
      steps { echo 'Create/update ConfigMap and rollout restart (to be implemented)' }
    }
  }
}
