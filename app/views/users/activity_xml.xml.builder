xml.instruct! 
xml.graph_data do
  xml.nodes do 
    for log in @logs
      # user node
      xml.node(
      "id" => log.user.id, 
      "label" => log.user.login, 
      "tooltip" => log.user.login,
      "graphic_type" => "image",
      "graphic_image_url" => log.user.avatar_photo_url(:thumb)
      )
      
      # task node
      xml.node(
      "id" => log.logeable_id, 
      "label" => log.logeable.name,
      "tooltip" => log.logeable.name,
      "url" => url_for(log.logeable)
      )
    end
  end
  
  xml.edges do
     for log in @logs
       if log.user != current_user
        #user to other user
        xml.edge(
        "id" => current_user.id + log.user_id,
        "tail_node_id" => current_user.id,
        "head_node_id" => log.user_id,
        "tooltip" => "segue",
        "edge_line_color" => "#0000ff",
        "edge_line_thickness" => "2"
        )
      end
      #user to object
       xml.edge(
      "id" => log.id,
      "tail_node_id" => log.user_id,
      "head_node_id" => log.logeable_id,
      "tooltip" => log.action, #TODO mensagem 
      "bidirectional" => "true",
      "edge_line_color" => "#ff0000",
      "edge_line_thickness" => "3"
      )
     end
  end
end