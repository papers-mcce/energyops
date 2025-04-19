# Create an IoT Thing (via AWS CLI)
aws iot create-thing --thing-name "netio-1"

# Create and download certificates for your device
aws iot create-keys-and-certificate --set-as-active \
  --certificate-pem-outfile "certificate.pem.crt" \
  --private-key-outfile "private.pem.key"

# Create a policy for the device
aws iot create-policy --policy-name "netio-1-policy" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "iot:Publish", 
        "Resource": "arn:aws:iot:region:account-id:topic/sensors/data"
      }
    ]
  }'

# Attach the policy to the certificate
aws iot attach-policy --policy-name "netio-1-policy" --target "arn:aws:iot:region:account-id:cert/certificate-id"


  