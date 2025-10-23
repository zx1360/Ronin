import 'package:flutter/material.dart';

import 'package:torrid/features/todo/widgets/content/task_list_widget.dart';
import 'package:torrid/features/todo/widgets/sideBar/side_drawer.dart';
import 'package:torrid/features/todo/widgets/topbar/todo_topbar.dart';

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: TodoTopbar(),
      drawer: SideDrawer(),
      body: TaskListWidget(),
    );
  }
}
