# frozen_string_literal: true

require 'json'
require 'mechanize'
require 'twilio-ruby'
# require 'pry'

SEF_LOGIN_PAGE = 'https://www.sef.pt/_layouts/15/SEF.WebControls/LoginPage.aspx'
SEF_AGENDAMENTO_PAGE = 'https://www.sef.pt/pt/mySEF/Pages/agendamento.aspx'
AGENDAMENTO_PAGE_ERROR_SELECTOR = 'div.online-schedule>div>div.error-row>div>span'
AGENDAMENTO_PAGE_ERROR_TEXT = 'Não foram encontrados postos de atendimento para o serviço selecionado.'

def call_alert_phone(message)
  client = Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])
  client.calls.create(
    from: ENV['PHONE_FROM'],
    to: ENV['PHONE_TO'],
    # url: 'http://demo.twilio.com/docs/voice.xml'
    twiml: <<~TWIML
      <Response>
        <Say voice="Polly.Camila-Neural" language="pt-BR" loop="2">
          <break strength="strong"/>
          #{message}
        </Say>
      </Response>
    TWIML
  )
  puts 'Call placed using Twilio.'
end

def monitor_sef(event:, context:)
  mechanize = Mechanize.new

  form = mechanize.get(SEF_LOGIN_PAGE).form
  form['ucLoginMenu$txtUsername'] = ENV['SEF_LOGIN']
  form['ucLoginMenu$txtPassword'] = ENV['SEF_PWD']
  submit_button = form.button_with(value: 'Login')
  mechanize.submit(form, submit_button)
  agendamento_page = mechanize.get(SEF_AGENDAMENTO_PAGE)
  error_span = agendamento_page.css(AGENDAMENTO_PAGE_ERROR_SELECTOR)
  if error_span && error_span.text == AGENDAMENTO_PAGE_ERROR_TEXT
    puts 'No spots :('
    # call_alert_phone('Não há vagas para agendamento no SEF.')
  else
    puts 'OPEN SPOTS!'
    puts 'Placing call using Twilio.'
    call_alert_phone('Parecem existir vagas para agendamento no SEF. Entre agora no sítio para verificar.')
    return {
      statusCode: 200,
      body: {
        message: 'OPEN SPOTS!'
      }.to_json
    }
  end

  {
    statusCode: 200,
    body: {
      message: 'No spots :('
    }.to_json
  }
end
