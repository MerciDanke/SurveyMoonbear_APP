# frozen_string_literal: true

require 'dry/transaction'

module SurveyMoonbear
  # Return a deleted survey
  # Usage: DeleteSurvey.new.call(config: <config>, survey_id: "...")
  class DeleteSurvey
    include Dry::Transaction
    include Dry::Monads

    step :refresh_access_token
    step :delete_record_in_database
    step :delete_spreadsheet

    def refresh_access_token(config:, survey_id:)
      access_token = Google::Auth.new(config).refresh_access_token
      Success(access_token: access_token, survey_id: survey_id)
    rescue
      Failure('Failed to refresh GoogleSpreadsheetAPI access token.')
    end

    def delete_record_in_database(access_token:, survey_id:)
      deleted_survey = Repository::For[Entity::Survey].delete_from(survey_id)
      Success(access_token: access_token, deleted_survey: deleted_survey)
    rescue
      Failure('Failed to delete record in database.')
    end

    def delete_spreadsheet(access_token:, deleted_survey:)
      GoogleSpreadsheet.new(access_token)
                       .delete_spreadsheet(deleted_survey.origin_id)
      Success(deleted_survey)
    rescue
      Failure('Failed to delete spreadsheet.')
    end
  end
end