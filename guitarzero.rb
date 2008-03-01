require 'rubygems'
require 'camping'
require 'camping/session'
require 'builder'

Camping.goes :GuitarZero

# = Guitar Hero High Scores =
#
# Marcus Crafter <crafterm@redartisan.com>
# Lachlan Hardy <lachlan@lachstock.com.au>
#
# Based on Twatter by Tim Lucas <t.lucas@toolmantim.com>
#
module GuitarZero
  include Camping::Session
end

module GuitarZero::Models
  class Party < Base
    has_many :songs
  end
  class Song < Base
    has_many :scores
  end
  class Score < Base
    belongs_to :song
    def <=>(score)
      self.score <=> score.score
    end
  end
  
  class GuitarZeroScores < V 1.0
    def self.up
      create_table :guitarzero_scores, :force => true do |t|
        t.column :id,       :integer
        t.column :name,     :string
        t.column :score,    :integer
        t.column :song_id,  :integer
        t.column :created_at, :timestamp
      end
      create_table :guitarzero_songs, :force => true do |t|
        t.column :id,       :integer
        t.column :name,     :string
        t.column :created_at, :timestamp
      end
    end
    
    def self.down
      drop_table :guitarzero_scores
      drop_table :guitarzero_songs
    end
  end
  
  class AddParties < V 2.0
    def self.up
      create_table :guitarzero_parties, :force => true do |t|
        t.column :id,       :integer
        t.column :name,     :string
        t.column :created_at, :timestamp
      end
      add_column :guitarzero_songs, :party_id, :integer, :default => 1
    end
    
    def self.down
      drop_table :guitarzero_parties
      remove_column :guitarzero_songs, :party_id
    end
  end
  
end

module GuitarZero::Controllers
  class Parties < R '/'
    def get
      @parties = Party.find(:all)
      render :parties
    end
    def post
      if input.partyname.blank?
        redirect Parties
      end
      party = Party.find_by_name(input.partyname) || Party.create!(:name => input.partyname.strip)
      redirect(Scores, party.id)
    end
  end
  class Scores < R '/scores/(\d+?)'
    def get(party_id=nil)
      @party = Party.find(party_id)
      @songs = @party.songs
      render :scores
    end
    def post(party_id)
      if input.name.blank? || input.score.blank? || input.song.blank?
        redirect Scores        
      end
      song = Song.find_by_name_and_party_id(input.song, party_id) || Song.create!(:name => input.song.strip, :party_id => party_id)
      song.scores.create(:score => input.score, :name => input.name.strip)
      
      @songs = Song.find(:all)
      redirect(Scores, party_id)
    end
  end
  class Static < R '/static/(.+)'         
    MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript', '.jpg' => 'image/jpeg', '.gif' => 'image/gif'}
    PATH = File.expand_path(File.dirname(__FILE__))

    def get(path)
     @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
     unless path.include? ".." # prevent directory traversal attacks
       @headers['X-Sendfile'] = "#{PATH}/static/#{path}"
     else
       @status = "403"
       "403 - Invalid path"
     end
    end
  end
  class Atom < R '/atom.xml'
    def get
      @scores = Score.find(:all)
      _atom(Builder::XmlMarkup.new)
    end
  end
end

module GuitarZero::Views
  def layout
    html do
      head do
        title 'guitar hero high scores'
        link :rel => 'stylesheet', :type => 'text/css', :href => '/static/guitarzero.css', :media => 'screen'
        link :href => R(Atom), :rel => "alternate", :type => "application/atom+xml"
        script(:src => "/static/prototype.js", :type=>"text/javascript", :charset=>"utf-8") { self << " " }
        script(:src => "/static/guitarzero.js", :type=>"text/javascript", :charset=>"utf-8") { self << " " }
      end
      body do
        div.page! do
          div.content! do
            h1 do
              a 'Guitar Zero!', :href => R(Parties)
            end
            p.tagline "Don't be a guitar zero... Post your scores"
        
            div.container do
              self << yield
            end
          end
        end
      end
    end
  end
  def parties
    div.newParty do 
      form :action => R(Parties), :method => 'post' do
        label :for => 'partyname' do
          span 'Party'  
          input :name => 'partyname', :type => 'text', :class => 'focus-on-load', :id => 'partyname'
        end
        input :type => 'submit', :name => 'login', :value => 'Submit', :class => 'submit'
      end
    end
    
    @parties.each do |party|
      ul.party do
        li {a party.name, :href => "/scores/#{party.id}" }
      end
    end

  end
  def scores
    h2 "Rocking out at #{@party.name}!"
    
    div.newScore do
      form :action => R(Scores, @party.id), :id => 'add-score', :method => 'post' do
        label :for => 'name' do
          span 'Name'  
          input :name => 'name', :type => 'text', :class => 'focus-on-load', :id => 'name'
        end
        label :for => 'song' do
          span 'Song'
          input :name => 'song', :type => 'text', :id => 'song'
        end
        label :for => 'score' do
          span 'Score'
          input :name => 'score', :type => 'text', :id => 'score'
        end
        input :type => 'submit', :name => 'login', :value => 'Submit', :class => 'submit'
      end
    end
    
    div.hatom do
      @songs.each do |song|
        div.song do
          h2 song.name
          song.scores.sort.reverse.each do |score|
            dl.hentry(:id => "score#{score.id}") do
              dt.author.vcard {span.fn score.name} 
              dd(:class => 'entry-content entry-title') { score.score }
              dd.timestamp do
  #              a(:href => "#score#{score.id}") do   # Removed until we work out the fragment id display 
                  abbr.updated(:title => score.created_at.strftime('%Y-%m-%d %H:%M:%S')){score.created_at.strftime('%H:%M')}
  #              end
              end
            end
          end
        end
      end
    end
  end
  def _atom(builder)
    builder.feed :xmlns => 'http://www.w3.org/2005/Atom' do |b|
      b.title "Guitar Zero!"
      b.link  :rel => "self", :type => "application/atom+xml", :href => R(Atom)
      b.link  :href => R(Parties), :rel => "alternate", :type =>"text/html"
      
      b.generator :version => "1.0", :uri => R(Parties)
      
      b.updated @scores.first.created_at.xmlschema unless @scores.empty?
      @scores.each do |score|
        b.entry 'xml:base' => R(Parties) do
          b.author do
            b.name score.name
          end
          b.published score.created_at.xmlschema
          b.link :href => R(Parties), :rel => "alternate", :type => "text/html"
          b.title     "#{score.score}: New score registered for #{score.song.name} by #{score.name}"
          b.content   "#{score.name} scored #{score.score} on song #{score.song.name}"
        end
      end
    end
  end
end

def GuitarZero.create
    GuitarZero::Models.create_schema
    Camping::Models::Session.create_schema
end

