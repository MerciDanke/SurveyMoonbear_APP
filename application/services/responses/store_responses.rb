# frozen_string_literal: true

require 'dry/transaction'
require 'json'

module SurveyMoonbear
  module Service
    # Return nil
    # Usage: Service::StoreResponses.new.call(survey_id: "...", launch_id: "...", respondent_id: "...", responses: <params>, config:)
    class StoreResponses
      include Dry::Transaction
      include Dry::Monads

      START_TIME_INDEX = 0
      END_TIME_INDEX = 1
      URL_PARAMS_INDEX = 2

      step :fetch_survey_items
      step :create_response_entities_arr
      step :add_time_records_into_arr
      step :add_url_params_into_arr
      step :add_data_to_all_entities_for_storing
      step :send_to_responses_storing_queues

      private

      # input { survey_id:, launch_id:, respondent_id:, responses:, config: }
      def fetch_survey_items(input)
        survey = Repository::For[Entity::Survey].find_id(input[:survey_id])

        input[:pages] = survey.pages
        Success(input)
      rescue StandardError => e
        puts e
        Failure('Failed to fetch survey items with survey id.')
      end

      # input { ..., pages: }
      def create_response_entities_arr(input)
        input[:response_entities_arr] = []
        responses_updated_at = JSON.parse( input[:responses]['responses_updated_at'] )
      
        input[:pages].each do |page|
          page_index = page.index
          page.items.each do |item|
            next if item.type == 'Description' || item.type == 'Section Title' || item.type == 'Divider'
            updated_at = responses_updated_at[item.name] ? responses_updated_at[item.name].to_time : nil
            new_response = create_response_entity(page_index,
                                                  item,
                                                  input[:respondent_id],
                                                  input[:responses][item.name],
                                                  updated_at)
            input[:response_entities_arr].push(new_response)
          end
        end

        input[:page_index_for_other_data] = input[:pages].length
        Success(input)
      rescue StandardError => e
        puts e
        Failure('Failed to create survey items array.')
      end

      def create_response_entity(page_index, item, respondent_id, response, updated_at)
        item_json = JSON.generate(type: item.type,
                                  name: item.name,
                                  description: item.description,
                                  required: item.required,
                                  options: item.options)

        Entity::Response.new(
          id: nil,
          respondent_id: respondent_id,
          page_index: page_index,
          item_order: item.order,
          response: response,
          updated_at: updated_at,
          item_data: item_json
        )
      end

      # input { ..., response_entities_arr:, page_index_for_other_data: }
      def add_time_records_into_arr(input)
        start_time = Entity::Response.new(id: nil,
                                          respondent_id: input[:respondent_id],
                                          page_index: input[:page_index_for_other_data],
                                          item_order: START_TIME_INDEX,
                                          response: input[:responses]['moonbear_start_time'],
                                          updated_at: nil,
                                          item_data: nil)
        end_time = Entity::Response.new(id: nil,
                                        respondent_id: input[:respondent_id],
                                        page_index: input[:page_index_for_other_data],
                                        item_order: END_TIME_INDEX,
                                        response: input[:responses]['moonbear_end_time'],
                                        updated_at: nil,
                                        item_data: nil)
        time_records = [start_time, end_time]
        time_records.each { |record| input[:response_entities_arr].push(record) }

        Success(input)
      rescue StandardError => e
        puts e
        Failure('Failed to add time records into items array.')
      end

      # input { ... }
      def add_url_params_into_arr(input)
        unless input[:responses]['moonbear_url_params'].nil?
          url_param_item = Entity::Response.new(id: nil,
                                                respondent_id: input[:respondent_id],
                                                page_index: input[:page_index_for_other_data],
                                                item_order: URL_PARAMS_INDEX,
                                                response: input[:responses]['moonbear_url_params'],
                                                updated_at: nil,
                                                item_data: nil)
          input[:response_entities_arr].push(url_param_item)
        end

        Success(input)
      rescue StandardError => e
        puts e
        Failure('Failed to add url params into items array.')
      end

      # input { ... }
      def add_data_to_all_entities_for_storing(input)
        responses_hash = input[:response_entities_arr].map do |response_entity|
          res_hash = response_entity.to_h
          res_hash[:survey_id] = input[:survey_id]
          res_hash[:launch_id] = input[:launch_id]
          res_hash.delete(:id)  # id was used for creating entities
          res_hash
        end

        input[:responses_hash] = responses_hash
        Success(input)
      rescue StandardError => e
        puts e
        Failure('Failed to handle responses for storing.')
      end

      # input { ..., responses_hash }
      def send_to_responses_storing_queues(input)
        Messaging::Queue.new(input[:config].RES_QUEUE_URL, input[:config])
                        .send(input[:responses_hash].to_json)
        Success(nil)
      rescue StandardError => e
        puts e
        Failure('Failed to add new responses to queues.')
      end
    end
  end
end
