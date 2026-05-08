{{- define "aws-app.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "aws-app.labels" -}}
app.kubernetes.io/name: {{ include "aws-app.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "aws-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "aws-app.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
