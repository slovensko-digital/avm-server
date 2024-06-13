json.array! @integrations do |i|
  json.integration_id i.id
  json.platform i.platform
  json.display_name i.display_name
end
