pipeline {
  agent any
  options { timestamps(); ansiColor('xterm') }

  parameters {
    // mỗi dòng là một credentialsId kiểu "jenkins-file-cred" (Kubeconfig file credential)
    text(name: 'KUBE_CONTEXTS', defaultValue: '')

    // labels tham gia release name + dán labels
    string(name: 'ORG',     defaultValue: '',      description: 'organzation (optional), ex: sb, ptf, asean')
    string(name: 'ENV',     defaultValue: 'pilot', description: 'enviroment runtime (REQUIRED), ex: live, pilot, uat')
    string(name: 'SYSTEM',  defaultValue: '',      description: 'service system (optional), ex: t24, carddrp, payment,..')

    // workload + chart
    choice(name: 'WORKLOAD_KIND', choices: ['Deployment','StatefulSet'])
    string(name: 'CHART_LABEL',   defaultValue: 'example-workload', description: 'chartLabel (thư mục chart cũng trùng tên này)')
    string(name: 'NAMESPACE',     defaultValue: '')
    // image
    string(name: 'IMAGE_REPO',  defaultValue: 'nexus-img.seabank.com.vn', description: 'registry/repo prefix')
    string(name: 'IMAGE_NAME',  defaultValue: '',   description: 'Nếu để trống → mặc định = chartLabel')
    string(name: 'IMAGE_TAG',   defaultValue: '1.0.0', description: 'image tag')
    choice(name: 'IMAGE_PULL',  choices: ['IfNotPresent','Always'], description: 'imagePullPolicy')
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
          def lines = params.KUBE_CONTEXTS.split('\n')
          def chartDir = params.CHART_LABEL   // chart dir = chart label

          for (int i = 0; i < lines.size(); i++) {
            def clusterID = lines[i]?.trim()
            if (!clusterID) continue
            echo "=== Deploy to cluster cred: ${clusterID} (line ${i+1}) ==="

            withCredentials([file(credentialsId: "${clusterID}", variable: 'FILE')]) {
              // derive SITE: StatefulSet -> md5(clusterID)[0..2], Deployment -> ""
              def siteVal = sh(returnStdout: true, script: """
                set -e
                if [ "${params.WORKLOAD_KIND}" = "StatefulSet" ]; then
                  printf "%s" "${clusterID}" | md5sum | cut -c1-3
                else
                  echo ""
                fi
              """).trim()

              // RELEASE_NAME = org-site-env-system-chartLabel (bỏ phần rỗng)
              def parts = [params.ORG, siteVal, params.ENV, params.SYSTEM, params.CHART_LABEL]
              def releaseName = parts.findAll { it?.trim() }.join('-').replaceAll(/-+/, '-')

              // namespace gợi ý (đổi nếu muốn)
              def ns = params.NAMESPACE

              echo "SITE=${siteVal} | RELEASE_NAME=${releaseName} | NAMESPACE=${ns} | CHART_DIR=${chartDir}"

              // build --set-string cho Helm
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

              withEnv(["KUBECONFIG=${FILE}"]) {
                sh """
                  set -e
                  kubectl get ns "${ns}" >/dev/null 2>&1 || echo "Không tồn tại namespace ${ns}"

                  # lint
                  helm lint "${chartDir}"

                  # render để kích hoạt validate (fail sớm)
                  helm template "${releaseName}" "${chartDir}" \
                    --namespace "${ns}" \
                    -f "${chartDir}/values.yaml" \
                    ${extraSet}

                  # diff (optional)
                  if ! helm plugin list | grep -q "diff"; then
                    helm plugin install https://github.com/databus23/helm-diff || true
                  fi
                  helm -n "${ns}" diff upgrade "${releaseName}" "${chartDir}" \
                    -f "${chartDir}/values.yaml" \
                    ${extraSet} || true

                  # deploy
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
    }
  }

  post {
    success { echo "✅ Deploy OK (all kubeconfigs)" }
    failure { echo "❌ Deploy FAILED" }
  }
}
