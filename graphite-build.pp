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
    exec{"${build_path}/configure --prefix=${build_path}/package/usr && make && make install":
        cwd=>"${build_path}",
        timeout=>"-1",
        creates=>"${build_path}/package/usr",
        alias=>"make-node-${node_version}"
    }
}

class statsd-build{
    # arbitrary version number
    $statsd_version="0.1"

    package{"git-core":ensure=>present}
    exec{"/usr/bin/git clone git://github.com/etsy/statsd.git statsd-${statsd_version}":
        cwd=>"/opt/build",
        creates=>"/opt/build/statsd-${statsd_version}",
        require=>Package["git-core"],
        alias=>"clone-statsd"
    }
    file{["/opt/build/statsd-${statsd_version}/package",
    "/opt/build/statsd-${statsd_version}/package/opt",
    "/opt/build/statsd-${statsd_version}/package/etc",
    "/opt/build/statsd-${statsd_version}/package/etc/init",
    "/opt/build/statsd-${statsd_version}/package/opt/statsd"]: 
    ,require=>Exec["clone-statsd"]
    ,ensure=>directory}

    file{"/opt/build/statsd-${statsd_version}/package/opt/statsd/stats.js": 
    source=>"/opt/build/statsd-${statsd_version}/stats.js"
    ,require=>Exec["clone-statsd"]
    }
    file{"/opt/build/statsd-${statsd_version}/package/opt/statsd/config.js":
        source=>"/opt/build/statsd-${statsd_version}/config.js"
        ,require=>Exec["clone-statsd"]
    }
    file{"/opt/build/statsd-${statsd_version}/package/etc/statsd-config.js":
        content=>"{ graphitePort: 2003
        , graphiteHost: \"localhost\"
        , port: 8125 }",
    }
    exec{"/usr/bin/touch /opt/build/statsd-${statsd_version}/built.${statsd_version}":
        alias=>"make-statsd-${statsd_version}",
        creates=>"/opt/build/statsd-${statsd_version}/built.${statsd_version}",
        require=>[File["/opt/build/statsd-${statsd_version}/package/etc/statsd-config.js"],
        File["/opt/build/statsd-${statsd_version}/package/opt/statsd/config.js"],
        File["/opt/build/statsd-${statsd_version}/package/opt/statsd/stats.js"],
        File["/opt/build/statsd-${statsd_version}/package/etc/init/statsd.conf"]]
    }

    file{"/opt/build/statsd-${statsd_version}/package/etc/init/statsd.conf":
        content=>"description \"statsd server\"
        start on filesystem
        stop on runlevel [!2345]
        respawn
        exec sudo -u www-data sh -c \"/usr/bin/node /opt/statsd/stats.js /etc/statsd-config.js |logger \" "
    }
    make_deb{"statsd":
        version=>"${statsd_version}",
        package_name=>"statsd",
        depends=>"nodejs",
        description=>"statsd daemon"
    }



}

class startup{
    exec{"/usr/bin/apt-get update && touch /etc/apt-updated": creates=>"/etc/apt-updated" }
}
stage { "first": before => Stage[main] }
class {"startup": stage=>first}
include startup
include graphite-app-build
include node-js-build
include statsd-build
