pipeline {
  agent any
  options { timestamps(); ansiColor('xterm') }

  parameters {
    // Multiline text: mỗi dòng là một kube context
    text(name: 'KUBE_CONTEXTS', defaultValue: '')

    // Labels tham gia GHÉP release name + dán label
    string(name: 'ORG',     defaultValue: '',       description: 'org label (optional)')
    string(name: 'ENV',     defaultValue: 'pilot',  description: 'env label (REQUIRED)')
    string(name: 'SYSTEM',  defaultValue: '',       description: 'system label (optional)')

    // Workload + Chart
    choice(name: 'WORKLOAD_KIND', choices: ['Deployment','StatefulSet'], description: 'Kiểu workload')
    string(name: 'CHART_LABEL',   defaultValue: 'unknown',      description: 'chartLabel (thư mục chart cũng trùng tên này)')

    // Ảnh container
    string(name: 'IMAGE_REPO',    defaultValue: 'nexus-img.seabank.com.vn', description: 'registry/repo prefix')
    string(name: 'IMAGE_NAME',    defaultValue: '',   description: 'để trống → mặc định = chartLabel, điền → overrite label')
    string(name: 'IMAGE_TAG',     defaultValue: '1.0.0', description: 'image tag')
    choice(name: 'IMAGE_PULL',    choices: ['IfNotPresent','Always'], description: 'imagePullPolicy')
  }

  environment { HELM_TIMEOUT = '10m' }

  stages {

    stage('Checkout & Tools') {
      steps {
        checkout scm
        sh 'helm version && kubectl version --client || true'
      }
    }

    stage('Deploy') {
      steps {
        script {
          // Parse multiline -> list contexts (bỏ dòng trống & trim)
          def contexts = params.KUBE_CONTEXTS.readLines()
                           .collect { it.trim() }
                           .findAll { it }

          if (contexts.isEmpty()) { error "KUBE_CONTEXTS trống." }

          // CHART_DIR = CHART_LABEL (theo yêu cầu)
          def chartDir = params.CHART_LABEL

          contexts.each { ctx ->
            echo "=== Cluster: ${ctx} ==="

            // Tính SITE theo rule:
            // StatefulSet -> md5(ctx)[0..2]; Deployment -> ""
            def siteVal = sh(
              returnStdout: true,
              script: """
                kind="${params.WORKLOAD_KIND}"
                ctx="${ctx}"
                if [ "$kind" = "StatefulSet" ]; then
                  printf "%s" "$ctx" | md5sum | cut -c1-3
                else
                  echo ""
                fi
              """
            ).trim()

            // RELEASE_NAME = org-site-env-system-chartLabel (bỏ thành phần rỗng)
            def parts = [params.ORG, siteVal, params.ENV, params.SYSTEM, params.CHART_LABEL]
            def releaseName = parts.findAll { it?.trim() }.join('-').replaceAll(/-+/, '-')

            // Namespace gợi ý: org-env (đổi nếu bạn muốn)
            def ns = [params.ORG, params.ENV].findAll { it?.trim() }.join('-')
            if (!ns) ns = 'default'

            echo "Computed: SITE=${siteVal} | RELEASE_NAME=${releaseName} | NAMESPACE=${ns} | CHART_DIR=${chartDir}"

            // Build --set-string cho Helm
            def extraSet = """
              --set-string chartLabel=${params.CHART_LABEL} \
              --set-string env=${params.ENV} \
              --set-string org=${params.ORG} \
              --set-string system=${params.SYSTEM} \
              --set workload.kind=${params.WORKLOAD_KIND} \
              --set-string workload.specs.image.repository=${params.IMAGE_REPO} \
              --set-string workload.specs.image.name=${params.IMAGE_NAME} \
              --set-string workload.specs.image.tag=${params.IMAGE_TAG} \
              --set-string workload.specs.image.pullPolicy=${params.IMAGE_PULL}
            """.trim()
            if (siteVal) { extraSet += " --set-string site=${siteVal}" }

            // Triển khai từng context
            sh """
              set -e
              kubectl config use-context "${ctx}"
              kubectl get ns "${ns}" >/dev/null 2>&1 || kubectl create ns "${ns}"

              # Lint chart
              helm lint "${chartDir}"

              # Render để kích hoạt validate (fail sớm)
              helm template "${releaseName}" "${chartDir}" \
                --namespace "${ns}" \
                -f "${chartDir}/values.yaml" \
                ${extraSet}

              # Diff (optional)
              if ! helm plugin list | grep -q "diff"; then
                helm plugin install https://github.com/databus23/helm-diff || true
              fi
              helm -n "${ns}" diff upgrade "${releaseName}" "${chartDir}" \
                -f "${chartDir}/values.yaml" \
                ${extraSet} || true

              # Deploy
              helm upgrade --install "${releaseName}" "${chartDir}" \
                --namespace "${ns}" --create-namespace \
                --atomic --timeout "${HELM_TIMEOUT}" --history-max 10 \
                -f "${chartDir}/values.yaml" \
                ${extraSet}
            """
          }
        }
      }
    }
  }

  post {
    success { echo "✅ Deploy OK (all contexts)" }
    failure { echo "❌ Deploy FAILED" }
  }
}
