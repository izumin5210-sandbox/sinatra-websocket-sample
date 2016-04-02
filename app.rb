# Bundler.requireをするとGemfileにあるファイルがすべてrequireされる
require 'bundler'
Bundler.require

# WebSocket用にマルチスレッド対応サーバであるthinを利用する（標準はWebrick）
set :server, 'thin'
# socketオブジェクトを管理するためのハッシュ
# roomのidがキーになっている
set :sockets, Hash.new { |h, k| h[k] = [] }

get '/:id' do
  # room idを取り出し
  @id = params[:id]

  if !request.websocket?
    # websocketのリクエストじゃないときはindex.erb返す
    erb :index
  else
    # websocketのリクエストだった時
    request.websocket do |ws|
      # websocketのコネクションが開かれたとき
      ws.onopen do
        # 最初のメッセージ送信
        ws.send("Hello World!")
        # ハッシュにidをキーにして保存
        settings.sockets[@id] << ws
      end

      # websocketのメッセージを受信したとき
      ws.onmessage do |msg|
        EM.next_tick do
          # 同じidにつながってるクライアントすべてにメッセージ送信
          settings.sockets[@id].each{|s| s.send(msg) }
        end
      end

      # websocketのコネクションが閉じられたとき
      ws.onclose do
        warn("websocket closed")
        # socketをハッシュから削除する
        settings.sockets[@id].delete(ws)
      end
    end
  end
end

# ここから下はindex.erb
__END__
@@ index
<html>
  <body>
     <h1>Simple Echo & Chat Server (<%= @id %>)</h1>
     <form id="form">
       <input type="text" id="input" value="send a message"></input>
     </form>
     <div id="msgs"></div>
  </body>

  <script type="text/javascript">
    window.onload = function(){
      (function(){
        var show = function(el){
          return function(msg){ el.innerHTML = msg + '<br />' + el.innerHTML; }
        }(document.getElementById('msgs'));

        var ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
        ws.onopen    = function()  { show('websocket opened'); };
        ws.onclose   = function()  { show('websocket closed'); }
        ws.onmessage = function(m) { show('websocket message: ' +  m.data); };

        var sender = function(f){
          var input     = document.getElementById('input');
          input.onclick = function(){ input.value = "" };
          f.onsubmit    = function(){
            ws.send(input.value);
            input.value = "send a message";
            return false;
          }
        }(document.getElementById('form'));
      })();
    }
  </script>
</html>
