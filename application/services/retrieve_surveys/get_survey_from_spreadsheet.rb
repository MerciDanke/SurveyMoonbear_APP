# frozen_string_literal: true

require 'dry/transaction'

module SurveyMoonbear
  # Return a survey entity from spreadsheet
  # Usage: GetSurveyFromSpreadsheet.new.call(spreadsheet_id: "...", current_account: {...})
  class GetSurveyFromSpreadsheet
    include Dry::Transaction
    include Dry::Monads

    step :read_spreadsheet

    def read_spreadsheet(spreadsheet_id:, current_account:)
      google_api = Google::Api.new(current_account['access_token'])
      spreadsheet = Google::SurveyMapper.new(google_api)
                                        .load(spreadsheet_id, current_account)
      Success(spreadsheet)
    rescue
      Failure('Failed to read spreadsheet survey.')
    end
  end
end