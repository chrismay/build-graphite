class graphite-app-build{
    package{["curl","build-essential","python-software-properties"]:ensure=>present}
package{["python-cairo",
         "python-twisted",
         "python-ldap",
         "libapache2-mod-python",
         "python-django",
         "python-pysqlite2",
         "memcached","python-memcache"]: ensure=>present}
 
    file{["/opt","/opt/build"]: ensure=>directory}

    include whisper-build
    include carbon-build
    include graphite-build
    include nodejs
}
class whisper-build{
   python-build{"whisper": version=>"0.9.6",creates_dir=>"usr"}
   make_deb{"whisper":
       version=>"0.9.6",
       description=>"Whisper RRD library",
       depends=>"python"}
}

class carbon-build{
   python-build{"carbon": version=>"0.9.6"}
   make_deb{"carbon": version=>"0.9.6",
        description=>"Carbon graph storage backend",
        depends=>"graphite-whisper"
   }
}
class graphite-build{
   python-build{"graphite-web": version=>"0.9.6"}
   make_deb{"graphite-web":
       version=>"0.9.6",
       description=>"graphite web ui",
       depends=>"graphite-carbon",
       package_name=>"graphite-web"
   }
}
class nodejs{
 exec{"/usr/bin/add-apt-repository ppa:jerome-etienne/neoip && /usr/bin/apt-get update": 
   alias=>"add-nodejs-repo"
   ,require=>Package["python-software-properties"]
   ,creates=>"/etc/apt/sources.list.d/jerome-etienne-neoip-lucid.list"
} 
 package{nodejs: ensure=>present, require=>Exec["add-nodejs-repo"]}
}

define make_deb($version,$depends,$description,$package_name="UNDEF" ){
  $pkg_name=$package_name?{
  "UNDEF"=>"graphite-${name}",
  default=>"${package_name}"
  }
  $destdir="/opt/build/${name}-${version}"
    file{"${destdir}/package/DEBIAN": 
      ensure=>directory}
    file{"${destdir}/package/DEBIAN/control": 
        content=>template("/vagrant/control.erb")
    }
    exec{"/usr/bin/dpkg --build package/ ${name}-${version}_all.deb":
        cwd=>$destdir,
        require=>[Exec["make-${name}-${version}"],File["${destdir}/package/DEBIAN/control"]],
        creates=>"${destdir}/${name}-${version}_all.deb"
    }

}

define python-build($version,$creates_dir="opt"){
  $destdir="/opt/build/${name}-${version}"
  file{"${destdir}/package": 
     ensure=>directory,
     require=>Exec["get-source-${name}-${version}"]
  }

  graphite-package-source{"$name": version=>$version}
  exec{"/usr/bin/python ${destdir}/setup.py install --root=./package":
    creates=>"${destdir}/package/${creates_dir}"
    ,cwd=>"${destdir}"
    ,require=>[File["${destdir}/package"],Exec["get-source-${name}-${version}"]]
    ,alias=>"make-${name}-${version}"
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
class startup{
   exec{"/usr/bin/apt-get update": }
}
stage { "first": before => Stage[main] }
class {"startup": stage=>first}
include startup
include graphite-app-build
