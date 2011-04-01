class graphite-app-build{
    package{["curl","build-essential","python-software-properties"]:ensure=>present}
package{["python-cairo","python-twisted","python-ldap","libapache2-mod-python","python-django","python-pysqlite2","memcached","python-memcache"]: ensure=>present}
 
    file{["/opt","/opt/build"]: ensure=>directory}

    include whisper-build
    include carbon-build
    include graphite-build
    include nodejs
}
class whisper-build{
   python-build{"whisper": version=>"0.9.6"}
}

class carbon-build{
   python-build{"carbon": version=>"0.9.6"}
}
class graphite-build{
   python-build{"graphite-web": version=>"0.9.6"}
}
class nodejs{
 exec{"/usr/bin/add-apt-repository ppa:jerome-etienne/neoip && /usr/bin/apt-get update": 
   alias=>"add-nodejs-repo"
   ,require=>Package["python-software-properties"]
   ,creates=>"/etc/apt/sources.list.d/jerome-etienne-neoip-lucid.list"
} 
 package{nodejs: ensure=>present, require=>Exec["add-nodejs-repo"]}
}

define python-build($version){
  $destdir="/opt/build/${name}-${version}"
  file{"${destdir}/package": ensure=>directory}

  graphite-package-source{"$name": version=>$version}
  exec{"/usr/bin/python ${destdir}/setup.py install --root=./package":
    creates=>"${destdir}/package/usr"
    ,cwd=>"${destdir}"
    ,require=>[File["${destdir}/package"],Exec["get-source-${name}-${version}"]]
  }
}

define graphite-package-source($version){
  $source_url="http://graphite.wikidot.com/local--files/downloads/${name}-${version}.tar.gz"
  exec{"/usr/bin/curl -L ${source_url} | /bin/tar zxvf - -C /opt/build":
   require=>File["/opt/build"]
   ,creates=>"/opt/build/${name}-${version}",
   alias=>"get-source-${name}-${version}"
}
}

include graphite-app-build
