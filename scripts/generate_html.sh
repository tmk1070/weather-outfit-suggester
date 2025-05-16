#!/bin/bash
set -euo pipefail

# ========== 設定 ==========
BASE_DIR="/opt/weather-site"
HTML_DIR="$BASE_DIR/html"
SCRIPT_DIR="$BASE_DIR/scripts"
DATA_FILE="$SCRIPT_DIR/data.json"
ORIGINAL_FILE="$HTML_DIR/original.html"
INDEX_FILE="$HTML_DIR/index.html"

# ========== .env 読み込み ==========
if [ -f "$BASE_DIR/.env" ]; then
    source "$BASE_DIR/.env"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') 警告: .env ファイルが見つかりません。環境変数またはデフォルトを使用します。"
fi

# ========== APIキーの確認 ==========
API_KEY="$OPENWEATHER_API_KEY"
CITY="$CITY_NAME"

if [[ -z "$API_KEY" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') エラー: APIキー（OPENWEATHER_API_KEY）が未設定です。"
    exit 1
fi

# ========== ログ関数 ==========
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

# ========== ファイル初期化 ==========
rm -f "$INDEX_FILE" "$DATA_FILE"
log "古いファイル(index.html, data.json)を削除しました。"

if [[ ! -f "$ORIGINAL_FILE" ]]; then
    log "エラー: original.html が存在しません。"
    exit 1
fi

cp "$ORIGINAL_FILE" "$INDEX_FILE"
log "original.html を index.html にコピーしました。"

# ========== 天気データ取得 ==========
if ! curl -s "https://api.openweathermap.org/data/2.5/weather?q=${CITY}&units=metric&appid=${API_KEY}" -o "$DATA_FILE"; then
    log "エラー: 天気情報の取得に失敗しました。"
    exit 1
fi

if ! jq -e .weather[0].main "$DATA_FILE" >/dev/null 2>&1; then
    log "エラー: OpenWeatherAPI のレスポンスに weather.main が含まれていません。"
    exit 1
fi

# ========== データ抽出 ==========
weather_main=$(jq -r '.weather[0].main' "$DATA_FILE")
temp_max=$(jq -r '.main.temp_max' "$DATA_FILE")
temp_min=$(jq -r '.main.temp_min' "$DATA_FILE")
temp_max_int=$(echo "$temp_max" | awk '{print int($1)}')
temp_min_int=$(echo "$temp_min" | awk '{print int($1)}')

# ========== 天気の日本語化 ==========
case "$weather_main" in
    "Clear") weather_jp="快晴" ;;
    "Clouds") weather_jp="曇り" ;;
    "Rain") weather_jp="雨" ;;
    "Drizzle") weather_jp="霧雨" ;;
    "Thunderstorm") weather_jp="雷雨" ;;
    "Snow") weather_jp="雪" ;;
    "Mist") weather_jp="霧" ;;
    "Haze") weather_jp="靄" ;;
    "Fog") weather_jp="濃霧" ;;
    *) weather_jp="不明" ;;
esac

# ========== 服装アドバイス ==========
if [ "$temp_max_int" -le 10 ]; then
    advice="コートや厚手の上着が必要です。"
elif [ "$temp_max_int" -le 20 ]; then
    advice="薄手のジャケットをおすすめします。"
else
    advice="Tシャツなどの軽装で大丈夫です。"
fi

# ========== HTMLプレースホルダ置換 ==========
replace_placeholder() {
    local key="$1"
    local value="$2"
    sed -i "s|{{${key}}}|$(printf '%s' "$value" | sed 's/[&/\]/\\&/g')|g" "$INDEX_FILE"
}

replace_placeholder "city_name" "$CITY"
replace_placeholder "weather_main" "$weather_jp"
replace_placeholder "temp_max" "$temp_max_int"
replace_placeholder "temp_min" "$temp_min_int"
replace_placeholder "advice" "$advice"

log "HTMLファイル生成が完了しました。"

