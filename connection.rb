class Connection
  def initialize ws
    @ws = ws
  end

  def send_rankings rankings
    data = {
      action: "country_clicked",
      rankings: rankings,
    }
    send data
  end

  def send_selected selected
    data = {
      action: "get_selected",
      selected: selected
    }
    send data
  end

  def send hash
    @ws.send hash.to_json
  end

  private :send
end
