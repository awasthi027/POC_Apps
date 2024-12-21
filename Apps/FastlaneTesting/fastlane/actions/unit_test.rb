module Fastlane
  module Actions
    module SharedValues
      TEST_METRICS = :TEST_METRICS
      CODE_COVERAGE = :CODE_COVERAGE
    end

    class UnitTestAction < Action

      def self.run(params)
         if params[:buildOnlyForTesting]
              buildForTesting
         else 
            runTest
         end 
      end

      def self.executeTestScan
            
            
      end

      def self.buildForTesting
            UI.message("Build scheme only for testing")
             other_action.scan(project: Actions.lane_context[SharedValues::WORKSPACE_NAME], 
              scheme: Actions.lane_context[SharedValues::WORKSPACE_SCHEME], 
              clean: false,
              build_for_testing: true,
              derived_data_path: Actions.lane_context[SharedValues::DERIVED_DATA_DIRECTORY],
              buildlog_path: Actions.lane_context[SharedValues::ARTIFACT_OUTPUT_DIRECTORY])
      end 

      def self.runTest
         UI.message("Running test for given scheme...")
              other_action.scan(project: Actions.lane_context[SharedValues::WORKSPACE_NAME], 
              scheme: Actions.lane_context[SharedValues::WORKSPACE_SCHEME], 
              clean: false,
              code_coverage: true,
              output_types: 'junit',
              output_files: 'junit-report.junit',
              derived_data_path: Actions.lane_context[SharedValues::DERIVED_DATA_DIRECTORY],
              buildlog_path: Actions.lane_context[SharedValues::ARTIFACT_OUTPUT_DIRECTORY])
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
         FastlaneCore::ConfigItem.new(key: :buildOnlyForTesting,
                                      env_name: "BUILD_ONLY_FOR_TESTING",
                                      description: "Give workspace name env file",
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
