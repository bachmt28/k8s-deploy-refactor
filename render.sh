ENV=uat
APP_LABEL=appapi
ORG=sb
SYSTEM=t24
VERSION=v2
rm -rf .rendered/*
#####
RELEASE_NAME=$ORG-$ENV-$SYSTEM-${APP_LABEL}-$VERSION
helm --debug template $RELEASE_NAME sbapp-cicd-chart/ \
--set system=$SYSTEM \
--set org=$ORG \
--set env=$ENV \
--set appLabel=$APP_LABEL \
--set version=$VERSION \
--output-dir .rendered

##### VS #####
RELEASE_NAME=$ORG-$ENV-$SYSTEM-${APP_LABEL}

helm --debug template $RELEASE_NAME virutalservice-cicd-chart/ \
--set system=$SYSTEM \
--set org=$ORG \
--set env=$ENV \
--set appLabel=$APP_LABEL \
--output-dir .rendered




ENV=uat
APP_LABEL=appapi
ORG=sb
SYSTEM=t24
VERSION=v1
RELEASE_NAME=$ORG-$ENV-$SYSTEM-${APP_LABEL}-$VERSION
helm upgrade --install $RELEASE_NAME sbapp-cicd-chart/ \
--set system=$SYSTEM \
--set org=$ORG \
--set env=$ENV \
--set appLabel=$APP_LABEL \
--set version=$VERSION

RELEASE_NAME=$ORG-$ENV-$SYSTEM-${APP_LABEL}
helm upgrade --install $RELEASE_NAME virutalservice-cicd-chart/ \
--set system=$SYSTEM \
--set org=$ORG \
--set env=$ENV \
--set appLabel=$APP_LABEL