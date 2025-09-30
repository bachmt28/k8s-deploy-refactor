pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
  }

  parameters {
    // Orchestrator quyết định context
    string(name: 'KUBE_CONTEXT', defaultValue: 'your-kube-context', description: 'kubectl/helm context (kubectl config use-context)')
    string(name: 'NAMESPACE',    defaultValue: 'example-live',     description: 'Kubernetes namespace để deploy')
    string(name: 'RELEASE_NAME', defaultValue: 'release-name',     description: 'Helm release name (Jenkins chịu trách nhiệm đặt)')

    // Chart + values
    string(name: 'CHART_DIR',    defaultValue: 'example-chart',    description: 'Đường dẫn chart')
    string(name: 'VALUES_FILE',  defaultValue: 'example-chart/values.yaml', description: 'values.yaml để dùng (có thể thay bằng values riêng)')

    // Labels (chỉ để dán label – không tham gia đặt tên)
    string(name: 'ORG',          defaultValue: '',     description: 'org label (optional)')
    string(name: 'ENV',          defaultValue: 'pilot',description: 'env label (REQUIRED)')
    string(name: 'SITE',         defaultValue: '',     description: 'site label (REQUIRED nếu StatefulSet)')
    string(name: 'SYSTEM',       defaultValue: '',     description: 'system label (optional)')

    // Workload identity
    string(name: 'CHART_LABEL',  defaultValue: 'example-workload', description: 'chartLabel (REQUIRED - định danh workload)')
    choice(name: 'WORKLOAD_KIND', choices: ['Deployment','StatefulSet'], description: 'Kiểu workload')

    // Ảnh container (chart helper imageRef sẽ ghép an toàn)
    string(name: 'IMAGE_REPO',   defaultValue: 'nexus-img.seabank.com.vn', description: 'registry/repo prefix (vd nexus-img...)')
    string(name: 'IMAGE_NAME',   defaultValue: '',     description: 'để trống → mặc định = chartLabel')
    string(name: 'IMAGE_TAG',    defaultValue: '1.0.0',description: 'tag')
    choice(name: 'IMAGE_PULL',   choices: ['IfNotPresent','Always'], description: 'imagePullPolicy')
  }

  environment {
    // Tuỳ môi trường: bật --atomic / timeout
    HELM_TIMEOUT = '5m'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'helm version && kubectl version --client'
      }
    }

    stage('Setup kube context') {
      steps {
        sh '''
          set -e
          kubectl config use-context "${KUBE_CONTEXT}"
          kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"
        '''
      }
    }

    stage('Helm lint') {
      steps {
        sh '''
          set -e
          helm lint "${CHART_DIR}"
        '''
      }
    }

    stage('Render & Validate (fail sớm)') {
      steps {
        sh '''
          set -e
          # Lắp set-string theo triết lý: labels/annotations chỉ để dán label
          EXTRA_SET="--set-string chartLabel=${CHART_LABEL} \
                     --set-string env=${ENV} \
                     --set-string org=${ORG} \
                     --set-string site=${SITE} \
                     --set-string system=${SYSTEM} \
                     --set workload.kind=${WORKLOAD_KIND} \
                     --set-string workload.specs.image.repository=${IMAGE_REPO} \
                     --set-string workload.specs.image.name=${IMAGE_NAME} \
                     --set-string workload.specs.image.tag=${IMAGE_TAG} \
                     --set-string workload.specs.image.pullPolicy=${IMAGE_PULL}"

          # Render thử để kích hoạt templates/00-validate.yaml
          helm template "${RELEASE_NAME}" "${CHART_DIR}" \
            --namespace "${NAMESPACE}" \
            -f "${VALUES_FILE}" \
            ${EXTRA_SET}
        '''
      }
    }

    stage('Diff (optional)') {
      steps {
        sh '''
          set -e
          if ! helm plugin list | grep -q "diff"; then
            helm plugin install https://github.com/databus23/helm-diff || true
          fi
          helm -n "${NAMESPACE}" diff upgrade "${RELEASE_NAME}" "${CHART_DIR}" \
            -f "${VALUES_FILE}" \
            --set-string chartLabel="${CHART_LABEL}" \
            --set-string env="${ENV}" \
            --set-string org="${ORG}" \
            --set-string site="${SITE}" \
            --set-string system="${SYSTEM}" \
            --set workload.kind="${WORKLOAD_KIND}" \
            --set-string workload.specs.image.repository="${IMAGE_REPO}" \
            --set-string workload.specs.image.name="${IMAGE_NAME}" \
            --set-string workload.specs.image.tag="${IMAGE_TAG}" \
            --set-string workload.specs.image.pullPolicy="${IMAGE_PULL}" || true
        '''
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          set -e
          helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
            --namespace "${NAMESPACE}" --create-namespace \
            --atomic --timeout "${HELM_TIMEOUT}" --history-max 10 \
            -f "${VALUES_FILE}" \
            --set-string chartLabel="${CHART_LABEL}" \
            --set-string env="${ENV}" \
            --set-string org="${ORG}" \
            --set-string site="${SITE}" \
            --set-string system="${SYSTEM}" \
            --set workload.kind="${WORKLOAD_KIND}" \
            --set-string workload.specs.image.repository="${IMAGE_REPO}" \
            --set-string workload.specs.image.name="${IMAGE_NAME}" \
            --set-string workload.specs.image.tag="${IMAGE_TAG}" \
            --set-string workload.specs.image.pullPolicy="${IMAGE_PULL}"
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Deploy OK: ${RELEASE_NAME} → ns=${NAMESPACE}"
    }
    failure {
      echo "❌ Deploy FAILED"
    }
  }
}
