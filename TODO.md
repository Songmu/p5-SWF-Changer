# utf8周りが汚い

parse\_stringしたdomだと
$dom->toString がUTF8を返さない
余計なis\_utf8判定が多いので、インターフェースを統一すべきか


