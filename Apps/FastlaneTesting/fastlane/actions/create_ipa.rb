module Fastlane
  module Actions
    module SharedValues
      BUILD_IPA_CUSTOM_VALUE = :BUILD_IPA_CUSTOM_VALUE
    end

    class CreateIpaAction < Action
      def self.run(params)
        pathToProjectFile = Actions.lane_context[SharedValues::WORKING_DIRECTORY]+"/"+Actions.lane_context[SharedValues::WORKSPACE_NAME]

        UI.important("Selected Export Method: " + params[:exportMethod].to_s)
        UI.important("Selected Build Congfiguration: " + params[:configuration].to_s)

        exportOptionsPlistPath = getExportOptionsPlistPathForCorrectExportMethod(exportMethod: params[:exportMethod])
        puts "exportOptionsPlistPath = " + exportOptionsPlistPath.to_s
        # build(
        #     exportOptionsPlistPath: exportOptionsPlistPath,
        #     configuration: params[:configuration],
        #     pathToProjectFile: pathToProjectFile
        # )
        archivePath = Actions.lane_context[SharedValues::WORKING_DIRECTORY] + "/" + Actions.lane_context[SharedValues::PROJECT_NAME] + ".xcarchive"
        puts "archivePath = " + archivePath.to_s

        archive(archivePath: archivePath)
        createIPA(exportOptionsPlistPath: exportOptionsPlistPath,
        archivePath:archivePath)
        UI.success("Successfully built application!")
      end

      def self.build(params)
        if Actions.lane_context[SharedValues::WORKSPACE_NAME].include? ".xcodeproj"
          UI.message("Building an xcode project not a workspace")
          # This is an xcode xcworkspace not a project
          other_action.gym(
            project: params[:pathToProjectFile],
            clean: true,
            scheme: Actions.lane_context[SharedValues::WORKSPACE_SCHEME].to_s,
            destination:"generic/platform=iOS",
            export_options: params[:exportOptionsPlistPath].to_s,
            configuration: params[:configuration].to_s,
            skip_profile_detection: true,
            xcargs: Actions.lane_context[SharedValues::XCARGS].to_s,
            derived_data_path: Actions.lane_context[SharedValues::DERIVED_DATA_DIRECTORY],
            archive_path: Actions.lane_context[SharedValues::ARTIFACT_OUTPUT_DIRECTORY],
            buildlog_path: Actions.lane_context[SharedValues::ARTIFACT_OUTPUT_DIRECTORY],
            output_name: Actions.lane_context[SharedValues::PROJECT_NAME] + ".ipa",
            output_directory: Actions.lane_context[SharedValues::ARTIFACT_OUTPUT_DIRECTORY]
          )
        else
          UI.message("Buildiong an xcode workspace not a project")
        end
      end

      def self.archive(params)
        command = "xcodebuild archive -scheme " 
        command = command + Actions.lane_context[SharedValues::WORKSPACE_SCHEME].to_s + " -sdk iphoneos "
        command = command + "-destination 'generic/platform=iOS' " + params[:exportOptionsPlistPath].to_s
        command = command +  "-archivePath " + params[:archivePath].to_s
        Action.sh(command)
      end 

      def self.createIPA(params)
        command = "xcodebuild -exportArchive -exportOptionsPlist " +  params[:exportOptionsPlistPath].to_s
        command = command + " -archivePath " + params[:archivePath].to_s
        command = command + " -exportPath ipafolder"
        Action.sh(command)
      end 

      def self.getExportOptionsPlistPathForCorrectExportMethod(params)
        path = Actions.lane_context[SharedValues::WORKING_DIRECTORY].to_s + "/"
        if params[:exportMethod].to_s == 'ad-hoc'
          if Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_ADHOC].to_s.empty?
            return nil
          end
          path = path + Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_ADHOC].to_s
        elsif params[:exportMethod].to_s == 'development'
          if Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_DEVELOPMENT].to_s.empty?
            return nil
          end
          path = path +  Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_DEVELOPMENT].to_s
        elsif params[:exportMethod].to_s == 'app-store'
          if Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_APPSTORE].to_s.empty?
            return nil
          end
          path = path +  Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_APPSTORE].to_s
        elsif params[:exportMethod].to_s == 'enterprise'
          if Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_ENTERPRISE].to_s.empty?
            return nil
          end
          path = path +  Actions.lane_context[SharedValues::EXPORT_OPTIONS_PLIST_ENTERPRISE].to_s
        else
          UI.user_error!("Unsupported export method: `" + params[:exportMethod].to_s + "` is not supported. Supported Export Methods include: ad-hoc, app-store, enterprise")
        end
        return path
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "A short description with <= 80 characters of what this action does"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :exportMethod,
                                       env_name: "FL_BUILD_IPA_EXPORT_METHOD",
                                       description: "The desired export method for exporting",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :configuration,
                                      env_name: "FL_BUILD_IPA_CONFIGURATION",
                                      description: "The desired build configuration",
                                      optional: true,
                                      default_value: "Release", #defaults to release
                                      is_string: true)
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end
    end
  end
end
