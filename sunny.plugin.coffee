sunny = require 'sunny'
mime = require 'mime'
http = require 'http'

doUpload = (docpad, container)->
    cloudHeaders = {"acl": 'public-read'}
    docpad.getFiles(write:true).forEach (file)->
        path = file.attributes.relativeOutPath
        data = file.get('contentRendered') || file.get('content') || file.getData()
        length = data.length
        type = mime.lookup path #file.get('contentType')

        headers = {
            "Content-Length": length,
            "Content-Type": type
        }

        if file.get('headers')
            for header in file.get('headers')
                headers[header.name] = header.value

        writeStream = container.putBlob path, {headers: headers, cloudHeaders: cloudHeaders}
        writeStream.on 'error', (err)->
            console.log "Error uploading #{path}"
        writeStream.on 'end', (results, meta)->
            console.log "Uploaded #{path}"
        writeStream.write data
        writeStream.end()

module.exports = (BasePlugin) ->
    class docpadSunyPlugin extends BasePlugin
        name: "sunny"

        writeAfter: (collection)->
            sunnyConfig = {
                provider: process.env.DOCPAD_SUNNY_PROVIDER,
                account: process.env.DOCPAD_SUNNY_ACCOUNT,
                secretKey: process.env.DOCPAD_SUNNY_SECRETKEY,
                ssl: process.env.DOCPAD_SUNNY_SSL
            }
            sunnyContainer = process.env.DOCPAD_SUNNY_CONTAINER
            sunnyConfig.ssl = ((typeof(sunnyConfig.ssl) is 'string') and (sunnyConfig.ssl.toLowerCase() is 'true'))

            if sunnyConfig.provider? and sunnyConfig.account? and sunnyConfig.secretKey? and sunnyContainer?

                docpad = @docpad
                connection = sunny.Configuration.fromObj(sunnyConfig).connection
                containerReq = connection.getContainer sunnyContainer, {validate: true}

                containerReq.on 'error', (err)->
                    console.log "Received error trying to connect to provider: \n #{err}"

                containerReq.on 'end', (results, meta)->
                    container = results.container
                    console.log "Got container #{container.name}."
                    doUpload docpad, container

                containerReq.end()
            else
                console.log 'One of the config variables is missing. Printing config:'
                console.dir sunnyConfig
                console.log "Container is #{sunnyContainer}"
