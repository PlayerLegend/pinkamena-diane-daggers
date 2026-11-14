class_name MenuWorld
extends GameWorld

func add_player(player: PlayerController):
    super(player)
    player.projectile_parent = null
    player.visible = false
    
