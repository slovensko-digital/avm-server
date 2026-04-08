json.array! @devices do |d|
  json.deviceId d.id
  json.platform d.platform
  json.displayName d.display_name
end
