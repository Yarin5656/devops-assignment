{{- define "rickmorty-service.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "rickmorty-service.fullname" -}}
{{- printf "%s" .Release.Name -}}
{{- end -}}
