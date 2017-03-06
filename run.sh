cd $FLOW_CURRENT_PROJECT_PATH

xcodeproj=`find ./ -maxdepth 1 -name "*.xcodeproj"`
if [ ! $xcodeproj ]; then
 echo ".xcodeproj not found"
else

  # Check shared sheme
  xcodeproj_shared_scheme_path=$xcodeproj/xcshareddata/xcschemes
  if [[ -d $xcodeproj_shared_scheme_path ]]; then
    num_of_shared_scheme=`ls $xcodeproj_shared_scheme_path | grep -c ".xcscheme"`
    if [ $num_of_shared_scheme -eq 0 ]; then
      echo '=== No shared scheme ==='
      echo 'Please share your scheme in Xcode: Product > Scheme > Manage Schemes > Check Shared'
      exit 1
    else
      echo "Shared scheme were founded"
    fi
  else
    echo '=== No shared scheme ==='
    echo 'Please share your scheme in Xcode: Product > Scheme > Manage Schemes > Check Shared'
    exit 1
  fi

  # Find DevelopmentTeam in xcodeproj
  TEAM_ARR=($(awk -F '=' '/DevelopmentTeam/ {print $2}' "$xcodeproj"/project.pbxproj))
  # Replace DevelopmentTeam value to none
  for s in ${TEAM_ARR[@]}
  do
    cmd="/DevelopmentTeam  = ${s}/DevelopmentTeam = \"\";/g"
    sed -i '' s"$cmd" "$xcodeproj"/project.pbxproj
  done

  # Find PROVISIONING_PROFILE in xcodeproj
  PROVISIONING_PROFILE_ARR=($(awk -F '=' '/PROVISIONING_PROFILE/ {print $2}' "$xcodeproj"/project.pbxproj))
  # Replace PROVISIONING_PROFILE value to none
  for s in ${PROVISIONING_PROFILE_ARR[@]}
  do
   cmd="/PROVISIONING_PROFILE = ${s}/PROVISIONING_PROFILE = \"\";/g"
   sed -i '' s"$cmd" "$xcodeproj"/project.pbxproj
  done

  # Find DEVELOPMENT_TEAM in xcodeproj
  DEVELOPMENT_TEAM_ARR=($(awk -F '=' '/DEVELOPMENT_TEAM/ {print $2}' "$xcodeproj"/project.pbxproj))
  # Replace DEVELOPMENT_TEAM value to none
  for s in ${DEVELOPMENT_TEAM_ARR[@]}
  do
   cmd="/DEVELOPMENT_TEAM = ${s}/DEVELOPMENT_TEAM = \"\";/g"
   sed -i '' s"$cmd" "$xcodeproj"/project.pbxproj
  done

  # Replace ProvisioningStyle 'Automatic' to 'Manual'
  sed -i '' s'/ProvisioningStyle = Automatic/ProvisioningStyle = Manual/g' "$xcodeproj"/project.pbxproj

  # Replace PROVISIONING_PROFILE_SPECIFIER to none
  sed -i -e "/PROVISIONING_PROFILE_SPECIFIER/d" "$xcodeproj"/project.pbxproj
fi

export FLOW_IOS_COMPILE_SDK="iphoneos"
params="-sdk $FLOW_IOS_COMPILE_SDK"

if [ -n "$FLOW_IOS_COMPILE_WORKSPACE" ]; then
    params="$params -workspace $FLOW_IOS_COMPILE_WORKSPACE"
fi

if [ -n "$FLOW_IOS_COMPILE_PROJECT" ]; then
    params="$params -project $FLOW_IOS_COMPILE_PROJECT"
fi

# 暂时不支持 -target
# if [ -n "$FLOW_IOS_COMPILE_TARGET" ]; then
#     params="$params -target $FLOW_IOS_COMPILE_TARGET"
#     build_out_dir=$FLOW_IOS_COMPILE_TARGET
# fi

if [ -n "$FLOW_IOS_COMPILE_SCHEME" ]; then
    params="$params -scheme $FLOW_IOS_COMPILE_SCHEME"
fi

if [ -n "$FLOW_IOS_COMPILE_CONFIGURATION" ]; then
    params="$params -configuration $FLOW_IOS_COMPILE_CONFIGURATION"
else
    params="$params -configuration Release"
    export FLOW_IOS_COMPILE_CONFIGURATION="Release"
fi

if [ -n "$FLOW_IOS_CODE_SIGN_IDENTITY" ]; then
    params="$params CODE_SIGN_IDENTITY=\"$FLOW_IOS_CODE_SIGN_IDENTITY\""
fi

if [ -n "$FLOW_MOBILEPROVISION_UUID" ]; then
    params="$params PROVISIONING_PROFILE=$FLOW_MOBILEPROVISION_UUID"
fi

export FLOW_OUTPUT_DIR=${FLOW_WORKSPACE}/output

cmd="xcodebuild build $params SYMROOT=${FLOW_OUTPUT_DIR} | tee ${FLOW_OUTPUT_DIR}/xcodebuild.log | xcpretty -s"
echo $cmd
eval $cmd

# fix xcodebuild 失败 但 $? 为 0
grep -o "BUILD SUCCEEDED" ${FLOW_OUTPUT_DIR}/xcodebuild.log &> /dev/null

# report html
# cat ${FLOW_OUTPUT_DIR}/xcodebuild.log | xcpretty -r  html --output ${FLOW_OUTPUT_DIR}/xcodebuild.html
