class AdminsController < ApplicationController
  include AdminsHelper
  before_action :admin?

  def show
    # byebug

    update_session(:page, :search, :sort)
    #get_answer
    data=Hash.new
    count=Hash.new
    all_submittion=Fullsubmission.all
    all_submittion.each do |submission|
      p '............................'
      p submission
      p submission.fullquestion
      
      t_ds_name=submission.fullquestion.ds_name
      t_ds_accession=submission.fullquestion.ds_accession
      if !data.has_key?([t_ds_name,t_ds_accession])
        data[[t_ds_name,t_ds_accession]]=Hash.new
      end
      if !count.has_key?(t_ds_accession)
        count[t_ds_accession]=0
      end
      
      if submission.choice!=nil
        count[t_ds_accession]+=1
        answer=submission.choice
        t_ques=submission.fullquestion.qcontent
        t_answer=submission.fullquestion.qanswer
        if !data[[t_ds_name,t_ds_accession]].has_key?(t_ques)
          data[[t_ds_name,t_ds_accession]][t_ques]=[0,0]
        end
        data[[t_ds_name,t_ds_accession]][t_ques][1]+=1
        if answer==t_answer
          data[[t_ds_name,t_ds_accession]][t_ques][0]+=1
        end
      end
      
    end
      p '++++++++++++++++++'
      p count 
      p data
      @data=data
      @count=count
  end


  def allusers
    update_session(:page, :query, :order)

    @users = find_conditional_users
        # byebug
    if @users == nil
      flash[:warning] = "No Results!"
    else
      # byebug
      get_answer
      @users.each { |user| user.get_accuracy }
      @users = @users.paginate(per_page: 15, page: params[:page])
    end
  end

  def promotewithgroup
      #All groups
      @poweradmin=current_user
      @all_groups = Group.all
      #debugger
  end


  def performassigngroup
      @group=Group.find(params[:id])
      #This action won't influence the identity of admins
      
      #Step: Arrange new admin
      if(params.has_key?(:user_ids))
        id=params.require(:user_ids)
      else
          flash[:warning] = "Please select a user!"
          redirect_to '/admin/promotewithgroup'
          return
      end
        
      @new_grp_admin=User.find_by_id(id[0])
      
      #3 situations: normal user; already grpadmin but in other grp; poweradmin
      if(@new_grp_admin.admin == true && @new_grp_admin.group_admin == false)
          #power admin -- do nothing
      elsif (@new_grp_admin.admin == true && @new_grp_admin.group_admin == true)
          #group admin -- do nothing
      else
          #User -- promote to be a group admin and assign him this group
          @new_grp_admin.update_attribute(:group_admin,true)
          @new_grp_admin.update_attribute(:admin,true)
      end
      @group.update_attribute(:admin_uid,id[0])
      flash[:success] = "Group Admin Identity for #{@group.name} Assigned successfully."
      redirect_to '/admin/promotewithgroup'
  end

  def managegrps
      #All groups
      @poweradmin=current_user
      @all_groups = Group.all      
      @all_grp_admins = User.where(:admin => true, :group_admin => true)
      #debugger
  end

  def rearrange
      #debugger
      @group=Group.find(params[:id])
      #This action will change grp admin
      #Step: Arrange new admin
      if(params.has_key?(:gadmin_ids))
        id=params.require(:gadmin_ids)
      else
          flash[:warning] = "Please select an admin!"
          redirect_to '/admin/manage_group_admins_groups'
          return
      end
        
      @new_admin_4_grp=User.find_by_id(id[0])
      @group.update_attribute(:admin_uid,id[0])
      @group.users << @new_admin_4_grp
      flash[:success] = "Group Admin Identity for #{@group.name} Assigned successfully."
      redirect_to '/admin/manage_group_admins_groups'      
  end


  def promote
    if params.has_key?(:operate)
      user = User.find_by_id(params[:operate])
      if user.group_admin
        user.update_attribute(:group_admin, false)
        user.update_attribute(:admin, false)
        flash[:success] = "#{user.name} was successfully demoted."
      else 
        user.update_attribute(:group_admin, true)
        user.update_attribute(:admin, true)
        flash[:success] = "#{user.name} was successfully promoted."
      end
      params.delete :operate
    end
      
    update_session(:page, :query, :order)
    
    
    @users = find_conditional_users

    # update user accuracy fields
    if !params.has_key?(:page) && !params.has_key?(:query) && !params.has_key?(:order)
      @users.each { |user| user.update_attribute(:accuracy, user.get_accuracy) }
    end
    # byebug

    if @users == nil
      flash[:warning] = "No Results!"
    else
      # byebug
      @users = @users.paginate(per_page: 15, page: params[:page])
    end
    
    
  end

  def configuration
    user = User.find_by_id(session[:user_id])
    if !user || !user.admin?
      flash[:warning] = "Permission denied!"
      redirect_to root_path
      return
    end
  end


  def dsstatistics
    #@histogram=[{"name" => "correct","data" => {"Gender" => 10,"aaa" => 30}},{"name" => "total","data" => {"Gender" => 20,"aaa" => 20}}]
    questions=params[:qdata]
    p questions
    gram=Hash.new
    gram=[{"name" => "correct","data" => {}},{"name" => "total","data" => {}},]
    questions.each do |k,a|
      gram[0]['data'][k]=a[0]
      gram[1]['data'][k]=a[1]
    end
    @histogram=Hash.new
    @histogram=gram
  end

  def statistics
    p params[:group_id]
    @group=Group.find_by_id(params[:group_id])
    @users=@group.get_users
    if @users==nil
      flash[:warning] = "No User in this group!"
      redirect_to '/profile'
      return
    end
    get_answer
    @users.each { |user| user.get_accuracy }
    @accuracies=Hash.new
    num=0
    while num.to_f<10 do
      @accuracies[num]=0;
      num+=1
    end
    @users.each do |usr|
      if Submission.find_by_user_id(usr.id)!=nil
        accuracy=Submission.find_by_user_id(usr.id).accuracy
        if accuracy==1
          @accuracies[9]+=1
        else
         accuracy*=10
         accuracy=accuracy.floor
         @accuracies[accuracy]+=1
        end
      end
    end
    @statistic=Hash.new
    @accuracies.each do |a,n|
      tmp=(a.to_f/10).round(1)
      @statistic[tmp.to_s+" to "+(tmp+0.1).round(1).to_s]=n.to_i
    end
  end

  def getcsv
    @dis = Disease.where(:closed => true)
    respond_to do |format|
      format.html
      format.csv { send_data @dis.to_csv }
      format.tsv { send_data @dis.to_csv(col_sep: "\t") }
    end
  end


  def config_update
    user = User.find_by_id(session[:user_id])
    if !user || !user.admin?
      flash[:warning] = "Permission denied!"
      redirect_to root_path
      return
    end

    str = params[:num_per_page]

    if str.size == 0 || (str =~ /^[-+]?\d+$/) == nil
      flash[:warning] = "Invalid input!"
      redirect_to '/config'
      return
    end

    new_value = params[:num_per_page].to_i

    if new_value < 5 || new_value > 20
      flash[:warning] = "Please enter a number in range (5..20)"
      redirect_to '/config'
      return
    end

    old_value = get_num_per_page
    set_num_per_page(new_value)
    flash[:success] = "Number of entries per page successfully switched from #{old_value} to #{new_value}"
    redirect_to '/config'
  end
    
  
end