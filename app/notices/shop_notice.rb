class ShopNotice

  attr_accessor :from, :to, :subject, :template, :locals

  def initialize(recipient, args = {})
    @template = args[:template]
    @email_notice = args[:email_notice] || true
    @paper_notice = args[:paper_notice] || true
    @mailer = args[:mailer] || EmployerMailer
  end

  def html
    ApplicationController.new.render_to_string template: @template, locals: @locals
  end

  def pdf
    WickedPdf.new.pdf_from_string(html)
  end

  def deliver
    send_email_notice if @email_notice
    send_paper_notice if @paper_notice
  end

  def send_email_notice
    @mailer.notice_email(self).deliver_now
  end

  def send_paper_notice
    notice_path = Rails.root.join('pdfs','notice.pdf')
    File.open(notice_path, 'wb') do |file|
      file << pdf
    end
  end
end



