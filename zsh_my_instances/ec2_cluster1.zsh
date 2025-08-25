################
# EC2 cluster1 #
################

# function ec2_id_cluster1() {
#    aws ec2 describe-instances --filters 'Name=placement-group-name,Values=cluster1' --query
# 'Reservations[].Instances[].[InstanceId]' --output text | tr '\n' ' ' | sed 's/ *$//g'
# }
  
  
# alias ec2_cluster1_start="aws ec2 start-instances --instance-ids $(ec2_id_cluster1)"
# alias ec2_cluster1_stop="aws ec2 stop-instances --instance-ids $(ec2_id_cluster1)"  



# alias ec2_start_hf1="aws ec2 start-instances --instance-ids $(ec2_id_hf1)"
# alias ec2_stop_hf1="aws ec2 stop-instances --instance-ids $(ec2_id_hf1)"  


# function date_time() {
#    echo $(date +%Y%m%d:%H%M%S) SecurityGroup $(ec2_id_hf1)
   
# }