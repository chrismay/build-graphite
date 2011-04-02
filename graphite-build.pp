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

define make_deb($version,$depends,$description,$package_name="UNDEF" ){
    $pkg_name=$package_name?{
        "UNDEF"=>"graphite-${name}",
        default=>"${package_name}"
    }
    $destdir="/opt/build/${name}-${version}"
    file{"${destdir}/package/DEBIAN": 
        ensure=>directory
    }
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

class  node-js-build{
  $node_version="v0.4.5"
  $build_path="/opt/build/node-${node_version}"
  package{["python","libssl-dev"]: ensure=>present}
  $source_url = "http://nodejs.org/dist/node-${node_version}.tar.gz"
  exec{"/usr/bin/curl -L ${source_url} | /bin/tar zxvf - -C /opt/build":
        require=>File["/opt/build"]
        ,creates=>"$build_path",
        alias=>"get-source-node-${node_version}"
  }
  file{"${build_path}/package": ensure=>directory, require=>Exec["get-source-node-${node_version}"]}
  make_deb{"node":
      version=>"${node_version}",
      package_name=>"nodejs",
     depends=>"",
     description=>"node.js server"
  }
  exec{"${build_path}/configure --prefix=${build_path}/package/opt/node && make && make install":
     cwd=>"${build_path}",
     timeout=>"-1",
     creates=>"${build_path}/package/opt",
     alias=>"make-node-${node_version}"
  }
}

class startup{
    exec{"/usr/bin/apt-get update": }
}
stage { "first": before => Stage[main] }
class {"startup": stage=>first}
include startup
include graphite-app-build
include node-js-build
