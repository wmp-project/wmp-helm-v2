[ -z "${SERVICE_NAME}" ] && exit
[ -z "${PARAMS}" ] && exit

for i in $PARAMS ; do
  aws ssm get-parameters --names "/${SERVICE_NAME}/$i" --region us-east-1 --with-decryption | jq -r '.Parameters[] | "\(.Name)=\"\(.Value)\""' | sed -e "s|/${SERVICE_NAME}/|export |" | tee -a /data/params
done
