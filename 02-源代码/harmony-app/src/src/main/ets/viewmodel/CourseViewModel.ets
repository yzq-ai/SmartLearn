export class CourseViewModel {
  public id: number = 0;
  public title: string = '';
  public description: string = '';
  public teacher: string = '';
  public progress: number = 0;
  public chapterCount: number = 0;
  public loading: boolean = false;

  static of(id: number, title: string, teacher: string): CourseViewModel {
    const vm: CourseViewModel = new CourseViewModel();
    vm.id = id;
    vm.title = title;
    vm.teacher = teacher;
    return vm;
  }
}
