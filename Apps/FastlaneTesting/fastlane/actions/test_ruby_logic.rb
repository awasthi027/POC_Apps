module Fastlane
  module Actions
    module SharedValues
      TEST_METRICS = :TEST_METRICS
      CODE_COVERAGE = :CODE_COVERAGE
    end

    class TestRubyLogicAction < Action
      def self.run(params)
          executeTestScan
      end

      def self.executeTestScan
              UI.message("Detecting active device...")
              other_action.scan(project: Actions.lane_context[SharedValues::WORKSPACE_NAME], 
              scheme: Actions.lane_context[SharedValues::WORKSPACE_SCHEME], 
             clean: false)
      end
   
      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Runs unit tests."
      end

      def self.details
        "The purpose of this action is to abstract away and simply the decision between
        calling scan with xcworkspace and scan with an xcodeproj."
      end

       def self.available_options
        [
         FastlaneCore::ConfigItem.new(key: :useSonarBuildWrapper,
                                      env_name: "WORKSPACE_NAME",
                                      description: "Give workspace name env file",
                                      optional: false,
                                      is_string: false,
                                      default_value: false), # the default value if the user didn't provide one
         FastlaneCore::ConfigItem.new(key: :buildForTestingOnly,
                                        env_name: "WORKSPACE_SCHEME",
                                        description: "Scheme name is needed to run the test env file",
                                        optional: false,
                                        is_string: false,
                                        default_value: false), # the default value if the user didn't provide one
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
      
    end
  end
end
