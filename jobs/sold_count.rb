require 'google/api_client'
require 'date'

# Update these to match your own apps credentials
service_account_email = ENV['GOOGLE_SERVICE_ACCOUNT'] # Email of service account
key_file = ENV['GOOGLE_KEY_PATH'] # File containing your private key
key_secret = 'notasecret' # Password to unlock private key
profileID = ENV['GOOGLE_ANALYTICS_PROFILE'] # Analytics profile ID.

if service_account_email && key_file && key_secret && profileID

  # Get the Google API client
  client = Google::APIClient.new(:application_name => 'Dashing Widget',
    :application_version => '0.01')

  # Load your credentials for the service account
  key = Google::APIClient::KeyUtils.load_from_pkcs12(key_file, key_secret)
  client.authorization = Signet::OAuth2::Client.new(
    :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
    :audience => 'https://accounts.google.com/o/oauth2/token',
    :scope => 'https://www.googleapis.com/auth/analytics.readonly',
    :issuer => service_account_email,
    :signing_key => key)

  # Start the scheduler
  SCHEDULER.every '1m', :first_in => 0 do

    # Request a token for our service account
    client.authorization.fetch_access_token!

    # Get the analytics API
    analytics = client.discovered_api('analytics','v3')

    # Start and end dates
    startDate = (DateTime.now - 7).strftime("%Y-%m-%d") # one week ago
    endDate = DateTime.now.strftime("%Y-%m-%d")  # now

    # Execute the query
    soldCount = client.execute(:api_method => analytics.data.ga.get, :parameters => {
      'ids' => "ga:" + profileID,
      'start-date' => startDate,
      'end-date' => endDate,
      'dimensions' => 'ga:year,ga:month,ga:day',
      'metrics' => 'ga:itemQuantity',
      # 'sort' => "ga:month"
    })

    points = []
    soldCount.data.rows.each do |data|
      year, month, day, units_sold = *data.map(&:to_i)

      timestamp = Time.new(year, month, day).to_i
      points << { x: timestamp, y: units_sold }
    end

    # Update the dashboard
    send_event('sold_count', { points: points })
  end

end
