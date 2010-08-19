class Seminar < ActiveRecord::Base

  #belongs_to :course
  has_one :course, :as => :courseable

  has_many :lesson, :as => :lesson

  SUPPORTED_VIDEOS = [ 'application/x-mp4',
                       'video/x-flv',
                       'application/x-flv',
                       'video/mpeg',
                       'video/quicktime',
                       'video/x-la-asf',
                       'video/x-ms-asf',
                       'video/x-msvideo',
                       'video/x-sgi-movie',
                       'video/x-flv',
                       'flv-application/octet-stream',
                       'video/3gpp',
                       'video/3gpp2',
                       'video/3gpp-tt',
                       'video/BMPEG',
                       'video/BT656',
                       'video/CelB',
                       'video/DV',
                       'video/H261',
                       'video/H263',
                       'video/H263-1998',
                       'video/H263-2000',
                       'video/H264',
                       'video/JPEG',
                       'video/MJ2',
                       'video/MP1S',
                       'video/MP2P',
                       'video/MP2T',
                       'video/mp4',
                       'video/MP4V-ES',
                       'video/MPV',
                       'video/mpeg4',
                       'video/avi',
                       'video/mpeg4-generic',
                       'video/nv',
                       'video/parityfec',
                       'video/pointer',
                       'video/raw',
                       'video/rtx' ]

  SUPPORTED_AUDIO = ['audio/mpeg', 'audio/mp3']

  has_attached_file :media

  # Callbacks
  before_validation :enable_correct_validation_group
  before_create :truncate_youtube_url

  # Validations Groups - Usados para habilitar diferentes validacoes dependendo do tipo d
  validation_group :external, :fields => [:external_resource, :external_resource_type]
  validation_group :uploaded, :fields => [:media]

  validates_presence_of :external_resource

  validates_attachment_presence :media
  validates_attachment_content_type :media,
    :content_type => (SUPPORTED_VIDEOS + SUPPORTED_AUDIO)
  validates_attachment_size :media,
    :less_than => 50.megabytes

  # Maquina de estados do processo de conversão
  acts_as_state_machine :initial => :waiting, :column => 'state'

  state :waiting
  state :converting, :enter => :transcode
  state :converted
  state :failed

  event :convert do
    transitions :from => :waiting, :to => :converting
  end

  event :ready do
    transitions :from => :converting, :to => :converted
    transitions :from => :waiting, :to => :converted
  end

  event :fail do
    transitions :from => :converting, :to => :fail
  end
  
  validate :validate_youtube_url
  
    
  def import_redu_seminar(url)
    course_id = url.scan(/aulas\/([0-9]*)/)
    
    @source = Course.find(course_id[0][0]) unless course_id.empty?
    # copia (se upload ou youtube)
    
    if @source and @source.public
      if @source.courseable_type == 'Seminar'
        if @source.courseable.external_resource_type.eql?('youtube')
          self.external_resource_type = 'youtube'
          self.external_resource = 'http://www.youtube.com/watch?v=' + @source.courseable.external_resource
          return [true, ""]
        elsif @source.courseable.external_resource_type.eql?('upload')
          self.external_resource_type = 'upload' # melhor ficar 'redu'?
          self.media_file_name = @source.courseable.media_file_name
          self.media_content_type = @source.courseable.media_content_type
          self.media_file_size = @source.courseable.media_file_size
          self.media_updated_at = @source.courseable.media_updated_at
          return [true, ""]
        end
        
      else
        return [false, "Aula não é um seminário"]
      end
    else
      return [false, "Link não válido ou aula não pública"]
    end
    
   end
    
  
  def validate_youtube_url
    if external_resource_type.eql?('youtube')
      capture = external_resource.scan(/youtube\.com\/watch\?v=([A-Za-z0-9._%-]*)[&\w;=\+_\-]*/)[0]
      
      #errors.add_to_base("Link inválido") # unless capture
    errors.add(:external_resource, "Link inválido") unless capture
    
#    elsif seminar.external_resource_type.eql?('redu')
#      capture = seminar.external_resource.scan(/redu\.com\.br\/aulas\/([A-Za-z0-9._%-]*)[&\w;=\+_\-]*/)[0][0]
#      
#      seminar.errors.add_to_base("Link inválido") unless capture
    
    end
    
  end
  

  def truncate_youtube_url
    if self.external_resource_type.eql?('youtube')
      capture = self.external_resource.scan(/youtube\.com\/watch\?v=([A-Za-z0-9._%-]*)[&\w;=\+_\-]*/)[0][0]
      # TODO criar validacao pra essa url
      self.external_resource = capture
    end
  end
  
  # Converte o video para FLV (é chamado do delayed job)
  def transcode
    require 'open-uri'
    # Baixando original convertendo e fazendo upload
    open("#{URI.parse(self.media.path)}") do |original|
      temp_file_path = RAILS_ROOT + "/tmp/" + media_file_name.split(".").first + ".flv"
      `nice -n +19 ffmpeg -y -i #{original.path} -ab 56 -ar 22050 -r 25 -s 640x480 #{temp_file_path}`
      open(temp_file_path){ |converted| self.media = converted }
      File.delete(temp_file_path)
    end
  end
  
  def video?
    SUPPORTED_VIDEOS.include?(self.media_content_type)
  end

  def audio?
    SUPPORTED_AUDIO.include?(self.media_content_type)
  end

  # Inspects object attributes and decides which validation group to enable
  def enable_correct_validation_group
    if self.external_resource_type != "upload"
      self.enable_validation_group :external
    else
      self.enable_validation_group :uploaded
    end
  end

  def type
    if video?
      self.media_content_type
    else
      self.external_resource_type
    end
  end
    
  def need_transcoding?
    self.video? or self.audio?
  end
end
