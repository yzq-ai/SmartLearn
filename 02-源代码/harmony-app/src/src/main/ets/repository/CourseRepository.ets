import { api } from '../common/ApiClient';
import { Course, CourseDetail } from '../common/Models';

export class CourseRepository {
  public async getCourses(): Promise<Course[]> {
    return api.getCourses();
  }

  public async getCourseDetail(id: number): Promise<CourseDetail> {
    return api.getCourse(id);
  }

  public async createCourse(title: string, description: string): Promise<Course> {
    return api.createCourse(title, description);
  }

  public async updateCourse(id: number, title: string, description: string): Promise<Record<string, object>> {
    return api.updateCourse(id, title, description);
  }
}

export const courseRepository: CourseRepository = new CourseRepository();
