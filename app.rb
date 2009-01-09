require 'rubygems'
require 'sinatra'
gem 'ruby-openid', '>= 2.0'
require 'openid/consumer'
require 'openid/extensions/sreg'
require 'openid/store/filesystem'

APP_ROOT  = File.dirname(__FILE__)
TEMP_PATH = APP_ROOT + '/tmp'
OID_STORE = OpenID::Store::Filesystem.new(TEMP_PATH)
OID_REQ_ATTRS = %w(nickname email) # required (set to nil for none)
OID_OPT_ATTRS = %w(gender) # optional (set to nil for none)

File.mkdir(TEMP_PATH) unless File.directory?(TEMP_PATH)

enable :sessions

get '/' do
  if session[:url]
    "you are logged in as #{session[:url]}"
  else
    "visit /login to get started"
  end
end

get '/login' do
  '<html><head></head><body><form method="POST">' +
  '<label>OpenID URL: <input name="url"/></label>' +
  '<input type="submit" value="Login"/></form></body></html>'
end

post '/login' do
  consumer = OpenID::Consumer.new(session, OID_STORE)
  oid_req = consumer.begin params[:url]
  sreg = OpenID::SReg::Request.new(OID_REQ_ATTRS, OID_OPT_ATTRS)
  oid_req.add_extension(sreg)
  redirect oid_req.redirect_url(realm, "#{realm}/login-complete")
end

get '/login-complete' do
  consumer = OpenID::Consumer.new(session, OID_STORE)
  response = consumer.complete(params, "#{realm}/login-complete")
  if response.status == :success
    sreg = OpenID::SReg::Response.from_success_response(response)
    sreg.data.each { |k, v| session[k.to_sym] = v }
    session[:url] = response.identity_url
    redirect '/'
  else
    'error'
  end
end

get '/logout' do
  session[:url] = nil
  redirect '/'
end

private

  def realm
    realm = "#{request.scheme}://#{request.host}"
    realm << ":#{request.port}" unless request.port == 80
    realm
  end
