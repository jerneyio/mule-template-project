#!/bin/bash

# This is better off in your ~/.bash_profile or equivalent
MULE_REPOS_DIRECTORY="/path/to/your/mule/repositories"

MULE_TEMPLATE_PROJ_NAME="jerneyio-mule-template-project"

function verify_dependencies() {
  command -v xml >/dev/null
  if [[ $? -eq 1 ]]; then
    printf "xmlstarlet is not installed. Please install with 'brew install xmlstarlet'\n"
  fi
}

function create_mule_proj_from_template() {
  
  ###########
  # Prompts #
  ###########
  
  local new_proj_name=""
  local git_remote_needed=""
  local git_origin=""
  local api_needed=""

  printf "TO EXIT: Ctrl+C\n"

  printf "Enter the new project name:\n"
  read new_proj_name
  printf "\n"

  printf "Does this project need a remote repository?\n"
  select git_remote_needed in yes no; do
    case $git_remote_needed in
      yes | no ) break ;;
             * ) printf "Choose 1 or 2:\n"
    esac
    printf "\n"
  done

  if [[ $git_remote_needed == "yes" ]]; then
    printf "Enter the remote repository URL (e.g. git@github.com:jerneyio/mule-template-project.git):\n"
    read git_origin
    printf "\n"
  fi

  printf "Does this project need an API?\n"
  select api_needed in yes no; do
    case $api_needed in
      yes | no ) break ;;
             * ) printf "Choose 1 or 2:\n"
    esac
  done

  ####################
  # Project Creation #
  ####################

  local proj_dir="${MULE_REPOS_DIRECTORY}/${new_proj_name}"

  printf "Creating new Mule project from template.\n"

  # Copy template project
  mkdir -p "${proj_dir}"
  cp -R . "${proj_dir}"

  # Remove .git and target directories
  rm -rf "${proj_dir}/.git"
  rm -rf "${proj_dir}/target"

  # Remove new_mule_proj.sh
  rm "${proj_dir}/new_mule_proj.sh"

  # Update template name reference to new project name
  grep -Rl --exclude-dir=.git --exclude-dir=target "${MULE_TEMPLATE_PROJ_NAME}" "${proj_dir}" \
    | xargs -I file sed -i "s/${MULE_TEMPLATE_PROJ_NAME}/${new_proj_name}/g" "file"

  ###########################
  # Removing API Components #
  ###########################

  if [[ $api_needed == "no" ]]; then
    printf "Removing API components.\n"

    # Remove api-related files
    rm -rf "${proj_dir}/src/main/resources/api"
    rm "${proj_dir}/src/main/mule/api.xml"

    # Remove HTTP Listener and api-autodiscovery from global.xml
    xml ed -L \
      -N api-gateway=http://www.mulesoft.org/schema/mule/api-gateway \
      -N http=http://www.mulesoft.org/schema/mule/http \
      -d '//api-gateway:autodiscovery' \
      -d '//http:listener-config' \
      "${proj_dir}/src/main/mule/global.xml"

    # Remove APIKit dependency
    xml ed -L \
      -d '//_:dependency[_:artifactId/text()="mule-apikit-module"]' \
      "${proj_dir}/pom.xml"

    # Remove http and api-related configs in *.properties files
    for f in $(find "${proj_dir}/src/main/resources" -type f -name "*.properties"); do
      
      # If you're running a Mac, make sure you have gnu-sed install and configured as the default sed:
      # brew install gnu-sed
      sed -i '/http-listener/d' "${f}"
      sed -i '/api/d' "${f}"
    done

    printf "API components removed.\n"
  fi

  ################
  # Git Handling #
  ################

  printf "Initializing git repository.\n"
  git -C "${proj_dir}" init
  git -C "${proj_dir}" checkout -b develop
  git -C "${proj_dir}" add -A
  git -C "${proj_dir}" commit -m "Initial commit"

  if [[ $git_remote_needed == "yes" ]]; then
    printf "Pushing project to remote.\n"
    git -C "${proj_dir}" remote add origin "${git_origin}"
    git -C "${proj_dir}" remote push -u origin develop
  fi

  printf "Finished creating new Mule project.\n"
}

verify_dependencies
create_mule_proj_from_template
