#!/usr/bin/env ruby
require 'mysql'

# Utility to synchronize class names from the puppet $modulepath manifest files
# and the node_classes table in the puppet dashboard database.

insertcount=deletecount=0
begin

# Open DB connection
cdb = Mysql.new('localhost', 'root', 'osis', 'dashboard', 3306)

# First get a list of all the classes defined in the manifest files
classarray=Array.new
Dir.foreach( "/etc/puppet/modules/" ) do |pdir|
  unless pdir == "." or pdir == ".." then
    classes = %x[egrep -s "^class" /etc/puppet/modules/#{pdir}/manifests/*.pp|awk '{print $2}'].chop
    if classes.size > 0 then
      classarray+=classes.split(/\n/)
    end
  end
end

# classarray element *may* have a curly brace on the end...
x=0
while x < classarray.size
  classarray[x] = classarray[x].sub('{','')
  x+=1
end
classarray.sort!

# Now a list of all the classes in the DB
dbarray=Array.new
res = cdb.query( "select name from node_classes;" )
res.each do |row|
  dbarray.push(row[0])
end
dbarray.sort!

# OK So now we have both arrary
# and we can loop through then comparing the elements
i = j = 0
while i < classarray.size and j < dbarray.size
  comp=classarray[i] <=> dbarray[j]
  if comp == 0
# do nothing
    #print "#{classarray[i]} == #{dbarray[j]}\n"
    i+=1
    j+=1
  elsif comp == 1
#   classarray > dbarray means there's a record in the DB that doesn't exist in the files
#   so delete it
    print "Removing record #{dbarray[j]}\n"
    cdb.query("delete from node_classes where name='#{dbarray[j]}';")
    deletecount +=1
    j+=1
  else
# classarray less then db means there's a recordd missing from the DB
#   so add it.
    print "Adding record #{classarray[i]}\n"
    cdb.query("insert into node_classes(name,created_at,updated_at) values ('#{classarray[i]}',SYSDATE(),SYSDATE());")
    insertcount +=1
    i+=1
  end
end

# Finally process any remaing records in either list
while i < classarray.size
  print "Adding record #{classarray[i]}\n"
  cdb.query("insert into node_classes(name,created_at,updated_at) values ('#{classarray[i]}',SYSDATE(),SYSDATE());")
  insertcount +=1
  i+=1
end

while j < dbarray.size
  print "Removing record #{dbarray[j]}\n"
  cdb.query("delete from node_classes where name='#{dbarray[j]}';")
  deletecount +=1
  j+=1
end
#rescue
end
cdb.close if cdb
print "#{insertcount} records added, #{deletecount} records removed\n"
