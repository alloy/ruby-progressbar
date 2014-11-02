require 'forwardable'

class ProgressBar
  class Base
    extend Forwardable

    def_delegators :output,
                   :clear,
                   :log,
                   :refresh

    def_delegators :progressable,
                   :progress,
                   :total

    def initialize(options = {})
      self.autostart    = options.fetch(:autostart,  true)
      self.autofinish   = options.fetch(:autofinish, true)
      self.finished     = false

      self.timer        = Timer.new(options)
      self.progressable = Progress.new(options)

      @title            = Components::Title.new(:title => options[:title])
      self.bar          = Components::Bar.new(options.merge(:progress => progressable))
      self.percentage   = Components::Percentage.new(:progress => progressable)
      self.rate         = Components::Rate.new(options.merge(:timer => timer, :progress => progressable))
      self.time         = Components::Time.new(options.merge(:timer => timer, :progress => progressable))

      self.output       = Output.detect(options.merge(:bar => self, :timer => timer))
      @format           = output.resolve_format(options[:format])

      start :at => options[:starting_at] if autostart
    end

    def start(options = {})
      clear

      timer.start
      update_progress(:start, options)
    end

    def finish
      output.with_refresh do
        self.finished = true
        progressable.finish
        timer.stop
      end unless finished?
    end

    def pause
      output.with_refresh { timer.pause } unless paused?
    end

    def stop
      output.with_refresh { timer.stop } unless stopped?
    end

    def resume
      output.with_refresh { timer.resume } if stopped?
    end

    def reset
      output.with_refresh do
        self.finished = false
        progressable.reset
        timer.reset
      end
    end

    def stopped?
      timer.stopped? || finished?
    end

    alias :paused? :stopped?

    def finished?
      finished || (autofinish && progressable.finished?)
    end

    def started?
      timer.started?
    end

    def decrement
      update_progress(:decrement)
    end

    def increment
      update_progress(:increment)
    end

    def progress=(new_progress)
      update_progress(:progress=, new_progress)
    end

    def total=(new_total)
      update_progress(:total=, new_total)
    end

    def progress_mark=(mark)
      output.refresh_with_format_change { bar.progress_mark = mark }
    end

    def remainder_mark=(mark)
      output.refresh_with_format_change { bar.remainder_mark = mark }
    end

    def title
      @title.title
    end

    def title=(title)
      output.refresh_with_format_change { @title.title = title }
    end

    def to_s(format = nil)
      self.format = format if format

      formatter.process(self, output.length)
    end

    def inspect
      "#<ProgressBar:#{progress}/#{total || 'unknown'}>"
    end

    def format=(other)
      @formatter = nil
      @format    = (other || output.default_format)
    end

    def formatter
      @formatter ||= ProgressBar::Format::Base.new(@format)
    end

  protected

    attr_accessor :output,
                  :timer,
                  :progressable,
                  :bar,
                  :percentage,
                  :rate,
                  :time,
                  :autostart,
                  :autofinish,
                  :finished

    def update_progress(*args)
      output.with_refresh do
        progressable.send(*args)
        timer.stop if finished?
      end
    end
  end
end
