require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def error_for_list_name(name)
    if session[:lists].any? { |list| list[:name] == name }
      'The list name must be unique.'
    elsif !(1..100).cover? name.size
      'The list name must between 1 and 100 characters.'
    end
  end

  def error_for_todo(task)
    if !(1..100).cover? task.size
      'The list name must between 1 and 100 characters.'
    end
  end

  def list_complete?(list)
    @all_done = true if total_todos(list) > 0 && total_uncompleted(list) == 0
  end

  def list_class(list)
    "complete" if list_complete(list)
  end

  def total_uncompleted(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def total_todos(list)
    list[:todos].size
  end

  def sort_lists(list)
    list.sort_by { |list| list_complete?(list) ? 1 : 0 }
  end

  def sort_todos(list)
    list.sort_by { |list| list[:completed] ? 1 : 0 }
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# view list of all lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# delete selected list
post '/lists/:id/delete' do
  @list_id = params[:id].to_i
  session[:lists].delete_at(@list_id)
  session[:success] = 'The list has been deleted.'
  redirect '/lists'
end

# update existing list
post '/lists/:id' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  new_list_name = params[:new_list_name].strip

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = new_list_name
    session[:success] = 'This list has been updated.'
    erb :list, layout: :layout
  end
end

# get a single list with an ID
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = sort_lists(session[:lists])[@list_id]
  @list[:id] = @list_id
  erb :list, layout: :layout
end

# edit the list name
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# add todos to a list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = sort_lists(session[:lists])[@list_id]
  todo = params[:todo].strip

  error = error_for_todo(todo)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false}
    @status = 'incomplete'
    session[:success] = 'The todo has been added to the list.'
    redirect "/lists/#{@list_id}"
  end 
  
end

# delete todo
post '/lists/:list_id/todos/:todo_id/delete' do
  @list_id = params[:list_id].to_i
  @list = sort_lists(session[:lists])[@list_id]
  todo_id = params[:todo_id].to_i

  @list[:todos].delete_at(todo_id)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{@list_id}"
end



# check all todos
post '/lists/:id/complete_all' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed.'
  erb :list, layout: :layout
end

# check and uncheck todo
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = sort_lists(session[:lists])[@list_id]
  sorted_todos = sort_todos(@list[:todos])
  todo_id = params[:todo_id].to_i
  checked = sorted_todos[todo_id][:completed]
  
  if !checked
    sorted_todos[todo_id][:completed] = true
    @status = 'complete'
  else
    sorted_todos[todo_id][:completed] = false
    @status = 'incomplete'
  end

  session[:success] = 'The todo has been updated.'
  erb :list, layout: :layout
end

