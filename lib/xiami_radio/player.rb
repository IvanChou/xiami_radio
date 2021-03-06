require 'audite'

module XiamiRadio
  # There is a player as you saw
  class Player

    attr_reader :track, :next_track, :radio

    def initialize(radio:, _playlist: nil)
      @radio = radio
      @player = Audite.new
      @view = View::Player.new

      @player.events.on :position_change, &method(:position_change)
      @player.events.on :complete, &method(:complete)
      @view.listen_on self

      trap(:SIGUSR1) { self.next }
      trap(:SIGUSR2) do
        File.open(XiamiRadio.track_info_swap, 'w') do |f|
          f.puts "#{self.track.title} - #{self.track.artist} - #{self.track.album_name}"
        end
      end
    end

    def play
      @track = @radio.next_track
      @player.queue @track.file_path
      @player.set_current_song
      @player.start_stream
      @player.thread.join
    end

    def next
      @track.downloader.stop
      if preloading?
        @track, @next_track = @next_track, nil
      else
        @track = @radio.next_track
        @player.queue @track.file_path
      end
      @player.request_next_song
    end

    def rewind
      @player.rewind
    end

    def forward
      @player.forward
    end

    def toggle
      @player.toggle
    end

    private

    def position_change(position)
      @view.refresh @track, position

      @track.record position.to_i if (120.0..123.0).include? position

      if !preloading? && position / @track.duration > 0.8
        @preloader = Thread.start do
          @next_track = @radio.next_track
          @player.queue @next_track.file_path
        end
      end
    end

    def complete
      @track.record
      @track, @next_track = @next_track, nil
    end

    def preloading?
      !@next_track.nil? || @preloader&.alive?
    end

    def self.play(radio)
      player = new radio: radio
      player.play
      player
    end
  end
end
