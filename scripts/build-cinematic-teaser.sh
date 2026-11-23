#!/usr/bin/env bash
# Собирает кинематографический тизер из 4 AI-кадров:
# медленный Ken Burns, затемнения между планами, 2.39:1 letterbox,
# плёночное зерно + виньетка + teal/orange градинг, синтезированный саундтрек
# (дождь из шума + низкий дрон + удар), титры.
#
# Требует ffmpeg с фильтрами zoompan/drawtext/noise/vignette/colorbalance.
#   FFMPEG=/path/to/ffmpeg ./scripts/build-cinematic-teaser.sh
set -euo pipefail

FFMPEG="${FFMPEG:-ffmpeg}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$HERE/assets/cinematic-teaser"
OUT="$HERE/assets/cinematic-teaser/neon-rain-teaser.mp4"
FONT="${FONT:-/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf}"

SHOT_LEN=4        # длительность плана, c
FPS=24
W=1920; H=804     # активная картинка 2.39:1
BAR=$(( (1080 - H) / 2 ))

printf 'Н Е О Н О В Ы Й   Д О Ж Д Ь' > "$SRC/title.txt"
printf 'тизер · 2026' > "$SRC/subtitle.txt"

# 4 плана: zoompan двигает кадр (push in / pull out), затем фейды в чёрное —
# стык двух затемнений даёт «dip to black», классический киношный переход.
FADE_OUT="$(awk -v a="$SHOT_LEN" 'BEGIN{printf "%.2f", a-0.45}')"

filter=""
for i in 1 2 3 4; do
  case $i in
    1) z="min(1+0.0010*on,1.10)"; x="iw/2-(iw/zoom/2)"; y="ih/2-(ih/zoom/2)-on*0.10" ;;
    2) z="min(1+0.0014*on,1.14)"; x="iw/2-(iw/zoom/2)"; y="ih/2-(ih/zoom/2)" ;;
    3) z="max(1.14-0.0012*on,1.00)"; x="iw/2-(iw/zoom/2)"; y="ih/2-(ih/zoom/2)" ;;
    4) z="min(1+0.0007*on,1.07)";  x="iw/2-(iw/zoom/2)"; y="ih/2-(ih/zoom/2)" ;;
  esac
  filter+="[$((i-1)):v]scale=3200:-2,setsar=1,"
  filter+="zoompan=z='$z':x='$x':y='$y':d=$((SHOT_LEN*FPS)):s=${W}x${H}:fps=${FPS},"
  filter+="fade=t=in:st=0:d=0.45,fade=t=out:st=${FADE_OUT}:d=0.45,"
  filter+="pad=1920:1080:0:${BAR}:black,setsar=1[v$i];"
done
filter+="[v1][v2][v3][v4]concat=n=4:v=1:a=0,"

# Единый грейд и «плёнка» поверх всего таймлайна.
filter+="eq=contrast=1.06:saturation=1.04:brightness=-0.01,"
filter+="colorbalance=rs=-0.04:bs=0.05:rm=0.03:bm=-0.03,"
filter+="vignette=PI/5,"
filter+="noise=alls=5:allf=t+u,"
filter+="unsharp=5:5:0.35:5:5:0.0"

# Титры: название в начале, подпись в финале.
filter+=",drawtext=fontfile='${FONT}':textfile='$SRC/title.txt':fontcolor=white:fontsize=62:"
filter+="x=(w-text_w)/2:y=(h-text_h)/2:shadowcolor=black@0.6:shadowx=2:shadowy=2:"
filter+="alpha='if(lt(t,0.9),0,if(lt(t,1.5),(t-0.9)/0.6,if(lt(t,3.1),1,if(lt(t,3.7),(3.7-t)/0.6,0))))'"
filter+=",drawtext=fontfile='${FONT}':textfile='$SRC/subtitle.txt':fontcolor=white@0.85:fontsize=30:"
filter+="x=(w-text_w)/2:y=h-${BAR}-110:"
filter+="alpha='if(lt(t,13.9),0,if(lt(t,14.6),(t-13.9)/0.7,1))'"

# Саундтрек: шум-«дождь», низкий дрон двумя синусами, удар на 13.8 c.
audio="anoisesrc=c=pink:r=44100:a=0.55:d=16:seed=42,highpass=f=500,lowpass=f=7000,volume=0.30[rain];"
audio+="sine=f=55:r=44100:d=16,volume=0.13[drone1];"
audio+="sine=f=82.5:r=44100:d=16,volume=0.06[drone2];"
audio+="aevalsrc='0.45*sin(2*PI*45*t)*exp(-3*t)':s=44100:d=2,adelay=13800|13800[boom];"
audio+="[rain][drone1][drone2][boom]amix=inputs=4:duration=longest:dropout_transition=0,"
audio+="afade=t=in:st=0:d=1.2,afade=t=out:st=14.4:d=1.6,volume=6.5[a]"

"$FFMPEG" -hide_banner -loglevel error -y \
  -i "$SRC/shot1.png" -i "$SRC/shot2.png" -i "$SRC/shot3.png" -i "$SRC/shot4.png" \
  -filter_complex "${filter}[vout];${audio}" \
  -map "[vout]" -map "[a]" \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -profile:v high -level 4.1 \
  -c:a aac -b:a 160k -ar 44100 \
  -t 16 -movflags +faststart \
  "$OUT"

echo "готово: $OUT"
