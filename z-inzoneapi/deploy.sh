# chmod +x deploy.sh && ./deploy.sh
gcloud builds submit --tag gcr.io/inzone-f93e4/inzoneapi
gcloud run deploy inzoneapi --image gcr.io/inzone-f93e4/inzoneapi --region us-central1 --env-vars-file envs.yaml