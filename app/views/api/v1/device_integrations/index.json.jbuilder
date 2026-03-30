json.array! @integrations do |i|
  json.integrationId i.id
  json.platform i.platform
  json.displayName i.display_name
end
